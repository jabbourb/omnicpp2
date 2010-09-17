" Description: Omni completion tokenizer
" Author: Bassam JABBOUR
" Note: Based on the original OmniCpp code

"{{{1 Parameters =======================================================

" From the C++ BNF
let s:keywords = ['asm', 'auto', 'bool', 'break', 'case', 'catch', 'char', 'class', 'const', 'const_cast', 'continue', 'default', 'delete', 'do', 'double', 'dynamic_cast', 'else', 'enum', 'explicit', 'export', 'extern', 'false', 'float', 'for', 'friend', 'goto', 'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 'operator', 'private', 'protected', 'public', 'register', 'reinterpret_cast', 'return', 'short', 'signed', 'sizeof', 'static', 'static_cast', 'struct', 'switch', 'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'and', 'and_eq', 'bitand', 'bitor', 'compl', 'not', 'not_eq', 'or', 'or_eq', 'xor', 'xor_eq']

" The order of items in this list is very important because we use this list to build a regular
" expression (see below) for tokenization
let s:operators = ['->*', '->', '--', '-=', '-', '!=', '!', '##', '#', '%:%:', '%=', '%>', '%:', '%', '&&', '&=', '&', '(', ')', '*=', '*', ',', '...', '.*', '.', '/=', '/', '::', ':>', ':', ';', '?', '[', ']', '^=', '^', '{', '||', '|=', '|', '}', '~', '++', '+=', '+', '<<=', '<%', '<:', '<<', '<=', '<', '==', '=', '>>=', '>>', '>=', '>']

" ORing of the previous lists items, with proper markers
let s:reOperator = '\V\^'.join(s:operators, '\|\^')
let s:reKeyword = '\V\C\^\<'.join(s:keywords, '\>\|\^\<').'\>'

" Token types and the associated regexps, order matters:
"   - digit : a C++ literal number
"   - string : a C++ literal string
"   - keyword : a valid C++ keyword (see list above)
"   - identifier : a variable/function/... name
"   - operator : an operator or punctutation sign
"   - unknown : will match any symbol not matched previously and up to
"   the end of the string
"
" Types are stored as a list of objects, each having a 'type' and
" 'regex' entry (plain dictionaries don't preserve the order of the
" elements).
"
" FIXME identifiers don't include all accepted C++ characters
function! s:addTypeRegex (name, regex)
    call add(s:TypeRegex, { 'name' : a:name, 'regex' : a:regex})
endfunc
let s:TypeRegex = []
" The digits regex first matches against hex numbers, then floating
" numbers, and finally normal integers
call s:addTypeRegex('digit','\^-\=\(0x\x\+\[UL]\=\|\(\d\+.\d\*\|.\d\+\)\(e-\=\d\+\)\=\[fFlL]\=\|\d\+\[UL]\=\)')
" All strings will be empty in sanitized code
call s:addTypeRegex('string','\^""')
call s:addTypeRegex('keyword', s:reKeyword)
call s:addTypeRegex('identifier', '\^\w\+')
call s:addTypeRegex('operator', s:reOperator)
call s:addTypeRegex('unknown', '\.\+')


" The regex used to match any token
let s:reTokenList = []
for type in s:TypeRegex
    call add(s:reTokenList, type.regex)
endfor
let s:reToken = '\V'.join(s:reTokenList,'\|')


"{{{1 Core =============================================================

" Tokenize a piece of code (a tokenText is a dictionary with keys {type,
" text}). Type 'unknown' is assigned to items that fail at
" classification.
"
" @param code a SANITIZED code string (see omnicpp#utils#SanitizeCode)
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
            if tokenText =~ '\V'.type.regex.'\$'
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

"{{{1 Interface wrappers ===============================================

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
