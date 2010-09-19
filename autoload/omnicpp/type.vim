" Author: Bassam JABBOUR
" Description: Type resolution routines


" Valid keywords
let s:reSpecifier = '(<'.join(g:omnicpp#syntax#KeySpecifier, '>\_s+|<').'>\_s+)'
" Valid type identifier
let s:reID = '('.s:reSpecifier.'@!&'.g:omnicpp#tokenizer#reIdentifier.')'
" Variable name prefix expression
let s:reVarPre = '\v'.s:reSpecifier.'*\zs'.s:reID.'(\_s*::\_s*'.s:reID.')*\ze\_s+'.s:reSpecifier.'*'

" Variable name suffix expression
let s:reVarPost = '\v\_s*[,=;]'


" Look up the type of a variable in the current local scope up to the
" cursor's position.
"
" @param var the name of the variable
" @return the type of the variable as a string if found, an empty string
" otherwise
function! omnicpp#type#GetLocalType(var)
    return get(omnicpp#scope#MatchLocal(s:reVarPre.'\V'.a:var.s:reVarPost, 1), 0, '')
endfunc

" Look up the type of a variable in the global scope of the current
" buffer up to the cursor's position.
"
" @param var the name of the variable
" @return the type of the variable as a string if found, an empty string
" otherwise
function! omnicpp#type#GetGlobalType(var)
    return get(omnicpp#scope#MatchGlobal(s:reVarPre.'\V'.a:var.s:reVarPost, 1), 0, '')
endfunc
