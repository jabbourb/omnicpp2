" Author: Bassam JABBOUR
" Description: C++ code tokenizer
"
" The tokenizer processes a code string and outputs the lexical elements
" found. Token types are as follow:
"   - digit : a C++ literal number
"   - string : a C++ literal string
"   - keyword : a valid C++ keyword (see syntax.vim)
"   - identifier : a variable/function/... name
"   - operator : an operator or punctutation sign (see syntax.vim)
"   - unknown : none of the above rules matched at the current position


"{{{1 Types definition

" Regexes
" Note: all regexes must be preceded by either (\v, \m, \M or \V) for
" the aggregated regex to work

" The digits regex first matches against hex numbers, then floating
" numbers, and finally plain integers
let s:reDigit = '\v^-=(0x\x+[UL]=|(\d+.\d*|.\d+)(e-=\d+)=[fFlL]=|\d+[UL]=)'
" Strings will have been emptied
let s:reString = '\m^""'
" Valide C++ identifiers (allows the $ character)
let s:reIdentifier = '\v^\w(\w|\d|\$)*'
" ORing keywords
let s:reKeyword = '\V\C\^\<'.join(g:CppKeywords, '\>\|\^\<').'\>'
" ORing operators
let s:reOperator = '\V\^'.join(g:CppOperators, '\|\^')
" The unknown type matches anything up to the end of the input
let s:reUnknown = '\v.+'

" Token types and the associated regexes, order matters.
" Types are stored as an ordered list of objects, each having 'name'
" and 'regex' entries.
let s:TypeRegex = []
call s:addTypeRegex('digit',        s:reDigit)
call s:addTypeRegex('string',       s:reString)
call s:addTypeRegex('keyword',      s:reKeyword)
call s:addTypeRegex('identifier',   s:reIdentifier)
call s:addTypeRegex('operator',     s:reOperator)
call s:addTypeRegex('unknown',      s:reUnknown)

function! s:addTypeRegex (name, regex)
    call add(s:TypeRegex, { 'name' : a:name, 'regex' : a:regex})
endfunc

" The regex used to match any token
let s:reTokenList = []
for type in s:TypeRegex
    call add(s:reTokenList, type.regex)
endfor
let s:reToken = join(s:reTokenList,'\v|')


"{{{1 Methods

" Tokenize a piece of code (a token is a dictionary with keys {type,
" text}). Type 'unknown' is assigned to items that fail at
" classification.
"
" @param code a SANITIZED code string (see omnicpp#utils#Sanitize)
" @return List of tokens
"
function! omnicpp#tokenizer#Tokenize(code)
    let result = []

    " Index pointing to the beginning of next match
    let matchStart = 0

    while 1
        " Skip any white spaces
        let spaceEnd = matchend(a:code, '\v^\s+', matchStart)
        if spaceEnd != -1
            let matchStart = spaceEnd
        endif

        " Match against the token regex
        let matchEnd = matchend(a:code, s:reToken, matchStart)
        " No more matches
        if matchEnd == -1 | break | endif
        let tokenText = strpart(a:code, matchStart, matchEnd-matchStart)

        let token = {}
        " Select the first item type whose regexp matches
        for type in s:TypeRegex
            if tokenText =~ type.regex.'\m$'
                let token['type'] = type.name
                let token['text'] = tokenText
                break
            endif
        endfor

        call add(result, token)

        " Move the first element pointer
        let matchStart = matchEnd
    endwhile

    return result
endfunc


" Tokenize the current instruction until the cursor position.
"
" @return list of tokens
"
function! omnicpp#tokenizer#TokenizeCurrentInstruction()
    let origPos = getpos('.')
    " Rewind until an instruction delimiter is found or beginning of
    " file is reached, jumping over comments or strings
    while 1
        let startPos = searchpos('[;{}]\|\%^', 'bW')
        if !omnicpp#utils#IsCursorInCommentOrString() || startPos == [1,1]
            break
        endif
    endwhile
    call setpos('.', origPos)
    return omnicpp#tokenizer#Tokenize(omnicpp#utils#GetCode(startPos, origPos[1:2], 1))
endfunc

" vim: fdm=marker
