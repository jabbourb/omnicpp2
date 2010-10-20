" Suffix when looking up a base in tag files.
" We want the base to match against the last part of an eventually
" qualified name.
let s:reSuffix = '\v[^:]*$'

" The omnifunc method
function! omnicpp#complete#Main(findstart, base)
    if a:findstart
        " We need to set s:mayComplete to 1 if completion is possible
        " for the second call
        if !omnicpp#utils#IsCursorInCommentOrString(1)
            let s:tokens = omnicpp#tokenizer#TokenizeInstruction()
            let start = s:FindStartOfCompletion()
            if start != -1
                let s:mayComplete = 1
                return start
            endif
        endif

        let s:mayComplete = 0
        return -1
    endif

    " Second call
    if !s:mayComplete
        return []
    endif

    " Cache includes for all subsequent operations
    let s:includes = omnicpp#include#CurrentBuffer()

    if !empty(s:tokens) && s:tokens[-1].text == '::'
        return omnicpp#complete#Qualified(a:base)
    else
        return omnicpp#complete#Any(a:base)
    endif
endfunc

" Search tag files for a qualified name, after retrieving the qualified
" name from the list of tokens; currently we only look up variables with
" the same exact qualified name (no implicit context nesting).
"
" @param base the base part of the name
"
" @return List of matches starting with base
"
func! omnicpp#complete#Qualified(base)
    let matches = []
    " Get qualifier from tokens
    let qualifier = s:GetQualifier()

    " Look up the exact qualified name
    " TODO also search contexts and using-declarations
    for item in taglist('\V\C\^'.qualifier.a:base.s:reSuffix)
        if omnicpp#tag#Match(item, s:includes)
            call add(matches, split(item.name,'::')[-1])
        endif
    endfor

    return matches
endfunc

" Search local variables and tag files for any name matching a given
" base, in a context visible at the cursor's location.
"
" @param base the base part of the name
" @return List of matches starting with base
"
func! omnicpp#complete#Any(base)
    " Local variables
    let matches = omnicpp#declare#LocalVars(a:base)

    " List of contexts to search
    let contexts = omnicpp#ns#CurrentDirectives() + omnicpp#ns#CurrentContexts()
    " List of imported members
    let decs = omnicpp#ns#CurrentDeclarations()

    " Look up unqualified names
    for item in taglist('\V\C\^'.a:base.s:reSuffix)
        if omnicpp#tag#Visible(item, s:includes) &&
                    \ (index(contexts, omnicpp#tag#Context(item)) >= 0
                    \ || omnicpp#tag#Declarations(item, decs))
            call add(matches, item.name)
        endif
    endfor

    call filter(matches, 'count(matches,v:val)==1')
    return matches
endfunc

" Used in the first invocation of Main() to find the base start col.
"
" @return the base start col, or -1 if no completion is possible
"
function! s:FindStartOfCompletion()
    let begin = -1
    if !empty(s:tokens)
        if index(['keyword', 'identifier'], s:tokens[-1].type) >= 0
            let begin = col('.') -1 -len(s:tokens[-1].text)
            " The last token isn't used anymore
            call remove(s:tokens, -1)
        elseif s:tokens[-1].type == 'operator'
            let begin = col('.') -1
        endif
    endif

    return begin
endfunc

func! s:GetQualifier()
    let qualifier = ''
    let last = ''

    while !empty(s:tokens)
        let cur = remove(s:tokens,-1)
        if (cur.text == '::' && last != '::') ||
                    \ (cur.type == 'identifier' && last == '::')
            let last = cur.text
            let qualifier = last . qualifier
        else
            break
        endif
    endwhile

    return qualifier
endfunc
