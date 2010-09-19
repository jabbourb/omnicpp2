" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace resolution

"{{{1 Parameters =======================================================

" The following regexes extract namespaces as XX::YY

" Regex used for matching using-declarations
let s:declarationRegex = '\C\v<using>\_s+\zs\w+(\_s*::\_s*\w+)+\ze\_s*;'
" Regex used for matching using-directives
let s:directiveRegex = '\C\v<using>\_s+<namespace>\_s+\zs\w+(\_s*::\_s*\w+)*\ze\_s*;'


"{{{1 Internal functions ===============================================

" Builds a list of namespaces made available in the current local scope
" up to the cursor's position; the strings are extracted by matching
" between the beginning and end of the regex.  If there is no local
" scope, returns an empty list.
"
" @param regex the regex used for matching namespace instructions
" @return List of namespaces strings
"
function! s:GetLocalUsing(regex)
    let usingList = []
    " Start of local scope
    let localStop = searchpair('{', '', '}', 'bnr')

    " If we are in global scope, do nothing
    if localStop
        let origPos = getpos('.')

        " Search backwards and put cursor at end of match
        while search(a:regex, 'bWe', localStop)
            " Look up the end of the current local scope, and ensure it
            " encompasses the position where the search started.
            " ex1:
            " {
            "   { using namespace std;}
            "   ...
            "   $cursor_position
            " }
            " ex2:
            " using namespace std; {
            "   ...
            "   $cursor_position
            " }
            let scopeEnd = searchpairpos('{', '', '}', 'n')
            if scopeEnd[0] >= origPos[1] && scopeEnd[1] >= origPos[2]
                let usingList += omnicpp#utils#GetInstructionBack(a:regex)
            endif
        endwhile

        call setpos('.', origPos)
    endif

    return usingList
endfunc

" Builds a list of namespaces made available in the global scope of the
" current buffer up to the cursor's position; the strings are extracted
" by matching between the beginning and end of the regex.
"
" @param regex the regex used for matching namespace instructions
" @return List of namespaces strings
"
" TODO: parse includes too
function! s:GetGlobalUsing(regex)
    let usingList = []
    let originalPos = getpos('.')
    while search(a:regex, 'bWe')
        " If we are inside a block, get out of it and continue the loop,
        " else add the match
        if !searchpair('{', '', '}', 'br')
            let usingList += omnicpp#utils#GetInstructionBack(a:regex)
        endif
    endwhile
    call setpos('.', originalPos)
    return usingList
endfunc


" Builds up a list of namespaces made available in the global scope of
" the given file; the strings are extracted by matching between the
" beginning and end of the regex.
"
" We don't use 'vimgrep' because as far as I could tell there is no easy
" way to search for instructions extending over multiple lines.
"
" @param regex the regex used for matching namespace instructions
" @return List of namespaces strings
"
" TODO: check that the matched instructions are actually in the global
" scope
function! s:GetGlobalUsingFromFile(regex, file)
    let usingList = []
    let f = join(readfile(a:file), ' ')
    let l:count = 1
    while 1
        let match = matchstr(f, a:regex, 0, l:count)
        if !empty(match)
            call add(usingList, substitute(match, '\s', '', 'g'))
            let l:count += 1
        else
            break
        endif
    endwhile
    return usingList
endfunc

"{{{1 Interface wrappers ===============================================

function! omnicpp#ns#GetGlobalUsingDirectives(file)
    return s:GetGlobalUsingFromFile(s:directiveRegex, a:file)
endfunc

function! omnicpp#ns#GetLocalUsingDeclarations()
    return s:GetLocalUsing(s:declarationRegex)
endfunc

function! omnicpp#ns#GetLocalUsingDirectives()
    return s:GetLocalUsing(s:directiveRegex)
endfunc

function! omnicpp#ns#GetGlobalUsingDeclarations()
    return s:GetGlobalUsing(s:declarationRegex)
endfunc

function! omnicpp#ns#GetGlobalUsingDirectives()
    return s:GetGlobalUsing(s:directiveRegex)
endfunc

" vim: fdm=marker
