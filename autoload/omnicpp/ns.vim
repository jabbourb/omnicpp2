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

"{{{1 Functions

" Find the full scope visible at the cursor position; this includes
" any namespace we are in, as well as containing classes.
"
" @return List of strings, each representing a namespace or class, each
" entry encompassing the ones that follow
"
func! omnicpp#ns#CurrentNameScope()
    let origPos = getpos('.')
    let namescope = []

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\_s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\_s*$')
        if !empty(ns)
            let namescope = [ns] + namescope
            continue
        endif

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\_s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\_s*(:|$)')
        if !empty(cls)
            let namescope = [cls] + namescope
            continue
        endif

        " Scope in function definition
        let instruct = substitute (instruct, ')\_s*$', '', '')
        let endPos = omnicpp#utils#SearchPairBack (instruct, '(', ')') - 1
        if endPos >= 0
            " We only check for compound names (:: separated) and
            " skip plain ones (and keywords btw)
            let namescope = split(substitute(matchstr(instruct[:endPos],
                        \ '\('.g:omnicpp#syntax#reIdSimple.'\_s*::\_s*)+\ze'.g:omnicpp#syntax#reIdSimple.'\_s*$'), '\s\+', '', 'g'),
                        \ '::') + namescope
        endif
    endwhile

    call setpos('.', origPos)
    return namescope
endfunc

" vim: fdm=marker
