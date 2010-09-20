" Author: Bassam JABBOUR
" Description: Type resolution routines

"{{{1 Regexes

" Valid keywords
let s:reSpecifier = '\V\C\(\<'.join(g:omnicpp#syntax#KeySpecifier, '\>\|\<').'\v>)'
" We need this because adding ((...)\_s*)* throws a *E51* "too many ("
let s:reSpecifierPre = '\V\C\(\_s\+\<'.join(g:omnicpp#syntax#KeySpecifier, '\>\|\_s\+\<').'\v>)'
let s:reSpecifierPost = '\V\C\(\<'.join(g:omnicpp#syntax#KeySpecifier, '\>\_s\+\|\<').'\v>\_s+)'

" Valid type identifier
let s:reId = '\v('.g:omnicpp#syntax#reIdFull.')'

" Master regex (declaration lookup)
"" Variable name prefix expression
"" We can assume that \v is always set
let s:reMasterPre = s:reId.'(\_s*::\_s*'.s:reId.')*'.s:reSpecifierPre.'*\_s*[*&]?\_s*'.s:reSpecifierPost.'*<\V\C'
"" Variable name suffix expression
let s:reMasterPost = '\v>\_s*.{-}\ze\_s*[,=;]'

" Sub regexes
"" Base type
let s:reBase = '^'.s:reId.'(\_s*::\_s*'.s:reId.')*'
"" Variable is a pointer if match
let s:rePointer = s:reBase.s:reSpecifierPre.'*\_s*\*\_s*'.s:reSpecifierPost.'*'
"" Variable is an array if match
let s:reArray =  '\v\[.{-}\]$'


"{{{1 Interface

" Look up the type of a variable in the current local scope up to the
" cursor's position.
"
" @param var the name of the variable
" @return a dictionary with the following keys:
"   - base: base type, no modifiers
"   - pointer: set to 1 if the variable is a pointer to 'base', 0
"   otherwise
"   - array: set to 1 if the variable is an array, 0 otherwise
"
function! omnicpp#type#GetLocalType(var)
    return s:GetTypeFromString(get(omnicpp#scope#MatchLocal(s:reMasterPre.a:var.s:reMasterPost, 1), 0, ''))
endfunc


" Look up the type of a variable in the global scope of the current
" buffer up to the cursor's position.
"
" @param, @return see GetLocalType
"
function! omnicpp#type#GetGlobalType(var)
    return s:GetTypeFromString(get(omnicpp#scope#MatchGlobal(s:reMasterPre.a:var.s:reMasterPost, 1), 0, ''))
endfunc


"{{{1 Auxiliary

" Builds the type object from the declaration string passed to it
" Returns an empty object if the base type isn't found
function! s:GetTypeFromString(str)
    let type = {'base' : '', 'pointer' : 0, 'array' : 0}

    let type.base = matchstr(a:str, s:reBase)
    if empty(type.base) | return {} | endif

    if match(a:str, s:rePointer)>=0 | let type.pointer = 1 | endif
    if match(a:str, s:reArray)>=0 | let type.array = 1 | endif

    return type
endfunc

" vim: fdm=marker
