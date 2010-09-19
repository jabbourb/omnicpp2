" Author: Bassam JABBOUR
" Description: Type resolution routines


" Variable name prefix expression
let s:reVarPre = ''
" Variable name suffix expression
let s:reVarPost = ''

" Look up the type of a variable in the current local scope up to the
" cursor's position.
"
" @param var the name of the variable
" @return the type of the variable as a string if found, an empty string
" otherwise
function! omnicpp#type#GetLocalType(var)
    return get(omnicpp#scope#MatchLocal(s:reVarPre.a:var.s:reVarPost, 1), 0, '')
endfunc

" Look up the type of a variable in the global scope of the current
" buffer up to the cursor's position.
"
" @param var the name of the variable
" @return the type of the variable as a string if found, an empty string
" otherwise
function! omnicpp#type#GetGlobalType(var)
    return get(omnicpp#scope#MatchGlobal(s:reVarPre.a:var.s:reVarPos, 1), 0, '')
endfunc
