" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace resolution


"{{{1 Parameters =======================================================

" The following regexes extract namespaces as XX::YY

" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives
let s:reDirective = '\C\v<using>\s+<namespace>\s+\zs\w+(\s*::\s*\w+)*\ze\s*;'

"{{{1 Interface wrappers ===============================================

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
