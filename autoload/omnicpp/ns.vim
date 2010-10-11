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

" When inside a namespace or class definition, or when implementing a
" method using its full qualified name, list all contexts visible from
" the current local scope
"
" @return List of namespaces
"
func! omnicpp#ns#CurrentContexts()
    let origPos = getpos('.')
    let singles = []

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\_s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\_s*$')
        if !empty(ns)
            let singles = [ns] + singles
            continue
        endif

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\_s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\_s*(:|$)')
        if !empty(cls)
            let singles = [cls] + singles
            continue
        endif

        " Scope in function definition
        let instruct = substitute (instruct, ')\_s*$', '', '')
        let endPos = omnicpp#utils#SearchPairBack (instruct, '(', ')') - 1
        if endPos >= 0
            " We only check for compound names (:: separated) and
            " skip plain ones (and keywords btw)
            let singles = split(substitute(matchstr(instruct[:endPos],
                        \ '\('.g:omnicpp#syntax#reIdSimple.'\_s*::\_s*)+\ze'.g:omnicpp#syntax#reIdSimple.'\_s*$'), '\s\+', '', 'g'),
                        \ '::') + singles
        endif
    endwhile

    call setpos('.', origPos)

    let contexts = []
    for idx in range(len(singles))
        let contexts += [join(singles[:idx], '::')]
    endfor
    return contexts
endfunc

" vim: fdm=marker
