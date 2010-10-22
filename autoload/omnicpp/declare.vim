" Author: Bassam JABBOUR
" Description: Type resolution routines

" === Regexes ==========================================================

" Keywords that define a type (int, char...)
let s:reVarKeyType = '\v<'.join(g:omnicpp#syntax#KeyType, '>|<').'>'
" Variable type regexp; can be either a keyword type or a custom
" (eventually qualified) identifer.
let s:reVarType = '\v\C'.s:reVarKeyType.'|'.g:omnicpp#syntax#reIdFull.'(\_s*::\_s*'.g:omnicpp#syntax#reIdFull.')*'
" Non-type keywords (specifiers) that can appear in a variable declaration
let s:reVarKeySpec = '\v<'.join(g:omnicpp#syntax#KeySpecifier, '>|<').'>'

" Master regexp (declaration lookup)
"
" Variable name prefix expression. First try to match lone declarations,
" or first declaration in a sequence; if that fails, try to match
" subsequent declarations in a sequence (names in a sequence must appear
" right after a comma, otherwise they might be on the right-hand of an
" initialization; and we can't ban '=' for sequences, since other
" variables might have been initialized before)
let s:reVarMasterPre = '\('.s:reVarType.')\_s*(\_[^:,;=]{-}(\*|\&|'.s:reVarKeySpec.')*\_s*|\_[^;]{-},\_s*[*&]=\_s*)\V\<'
" Variable name suffix expression
let s:reVarMasterPost = '\v>(\_s*\[[^]]*\])*\ze\_s*[,=;]'

" Sub regexes, to be matched against the string found using the master
" regexp
"
" Base type
let s:reVarSubType = '^'.s:reVarType
" In a sequence, the following is matched against the last declaration
" Variable is a pointer if match
let s:reVarSubPointer = '\*'
" Variable is an array if match
let s:reVarSubArray =  '\v\[.{-}\]$'

" === Functions ========================================================

" Builds the type object from the declaration string passed to it, by
" extracting the base type and any pointer/array information.
"
" @param str the code string corresponding to the variable's declaration
" @return a dictionary with the following keys:
"   - base: base type, no modifiers
"   - pointer: set to 1 if the variable is a pointer to 'base', 0
"   otherwise
"   - array: set to 1 if the variable is an array, 0 otherwise
" or an empty object if matching against the declaration failed.
"
func! omnicpp#declare#TypeFromString(str)
    let type = {'base' : '', 'pointer' : 0, 'array' : 0}

    let type.base = matchstr(a:str, s:reVarSubType)
    if empty(type.base) | return {} | endif

    " Get only the last declaration, which is the variable we want
    let single = split(a:str, ',')[-1]
    if match(single, s:reVarSubPointer)>=0 | let type.pointer = 1 | endif
    if match(single, s:reVarSubArray)>=0 | let type.array = 1 | endif

    return type
endfunc

" Look up the type of a variable in the current local scope up to the
" cursor's position.
"
" @param var the name of the variable
" @return the type of the variable, see FromString()
"
func! omnicpp#declare#LocalType(var)
    " Last match takes precedence
    return omnicpp#declare#TypeFromString(get(omnicpp#scope#MatchLocal(s:reVarMasterPre.a:var.s:reVarMasterPost), -1, ''))
endfunc

" Search for variables whose name matches a given base and declared in
" the local scope up to the cursor's position
"
" @param base the starting part of the variable's name
" @return List of matching names
"
func! omnicpp#declare#LocalVars(base)
    let vars = omnicpp#scope#MatchLocal(s:reVarMasterPre.'\zs'.a:base.'\v(\w|\d|\$)*>')
    " Filter duplicates
    return filter(vars, 'count(vars,v:val)==1')
endfunc
