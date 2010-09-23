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
function! omnicpp#type#LocalType(var)
    return s:GetTypeFromString(get(omnicpp#scope#MatchLocal(s:reMasterPre.a:var.s:reMasterPost, 1), 0, ''))
endfunc


" Look up the type of a variable. Will search in the following order:
" - Local scope
" - Local using declaration
" - Class scope
" - Global scope | Using directives | Global using declaration
"
" @param, @return see GetLocalType
"
function! omnicpp#type#Type(var)
    let type = omnicpp#type#LocalType(a:var)
    if !empty(type) | return type | endif

    " 'using XX::var' where XX::var is a type and var exists as a
    " variable is usually an error; therefor we assume XX::var to name a
    " variable.
    for dec in omnicpp#ns#LocalUsingDeclarations()
        if split(dec, '::')[-1] == a:var
            return s:TagSearchType(dec)
        endif
    endfor

    for cls in omnicpp#class#BaseClasses()
        let type = s:TagSearchType(cls.'::'.a:var)
        if !empty(type) | return type | endif
    endif

    let type = s:TagSearchType(omnicpp#ns#CurrentNS().a:var)
    if !empty(type) | return type | endif

    for dec in omnicpp#ns#GlobalUsingDeclarations()
        if split(dec, '::')[-1] == a:var
            return s:TagSearchType(dec)
        endif
    endfor

    for dir in (omnicpp#ns#LocalUsingDirectives() + omnicpp#ns#GetGlobalUsingDirectives())
        let type = s:TagSearchType(dir.'::'.a:var)
        if !empty(type) | return type | endif
    endfor
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

" Search tag files for the given qualified variable name, making sure
" the source file it appears in is visible from the current buffer.
function! s:TagSearchType(qualifiedName)
endfunc

" vim: fdm=marker
