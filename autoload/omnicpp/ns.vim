" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace resolution

"{{{1 Parameters =======================================================

" The following regexes extract namespaces as XX::YY

" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\_s+\zs\w+(\_s*::\_s*\w+)+\ze\_s*;'
" Regex used for matching using-directives
let s:reDirective = '\C\v<using>\_s+<namespace>\_s+\zs\w+(\_s*::\_s*\w+)*\ze\_s*;'


"{{{1 Internal functions ===============================================

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

function! omnicpp#ns#GlobalUsingDirectives(file)
    return s:GetGlobalUsingFromFile(s:reDirective, a:file)
endfunc

function! omnicpp#ns#LocalUsingDeclarations()
    return map(omnicpp#scope#MatchLocal(s:reDeclaration), 'substitute(v:val, " ", "", "g")')
endfunc

function! omnicpp#ns#LocalUsingDirectives()
    return map(omnicpp#scope#MatchLocal(s:reDirective), 'substitute(v:val, " ", "", "g")')
endfunc

function! omnicpp#ns#GlobalUsingDeclarations()
    return map(omnicpp#scope#MatchGlobal(s:reDeclaration), 'substitute(v:val, " ", "", "g")')
endfunc

function! omnicpp#ns#GlobalUsingDirectives()
    return map(omnicpp#scope#MatchGlobal(s:reDirective), 'substitute(v:val, " ", "", "g")')
endfunc

" vim: fdm=marker
