"{{{1 Main

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
    let s:includes = omnicpp#include#AllIncludes()

    if !empty(s:tokens) && s:tokens[-1].text == '::'
        let qualified = ''
        while !empty(s:tokens) && (s:tokens[-1].text == '::' || s:tokens[-1].type == 'identifier')
            let qualified = remove(s:tokens, -1).text . qualified
        endwhile
        return omnicpp#complete#Contexts(qualified.a:base)
    else
        return omnicpp#complete#Vars(a:base)
    endif
endfunc

"{{{1 Specific routines

" Return all the variables names starting with a given base and visible
" at the cursor's position.
func! omnicpp#complete#Vars(base)
    " Local variables
    let vars = omnicpp#declare#LocalVars(a:base)

    " Using declarations
    for dec in omnicpp#ns#LocalUsingDeclarations() + omnicpp#ns#GlobalUsingDeclarations()
        let decName = split(dec,'::')[-1]
        if match(decName, a:base) == 0
            let vars += [decName]
        endif
    endfor

    let vars += omnicpp#complete#Contexts(a:base)

    call filter(vars, 'count(vars,v:val)==1')
    return vars
endfunc

" Search for names starting with a given base in any base classes,
" namespaces or global contexts visible at the cursor's position
func! omnicpp#complete#Contexts(base)
    let matches = []
    " Using directives and any context visible at the cursor's position.
    " We want the variable name to be the last part of the full
    " qualified name.
    let tagQuery = '\V\C\^\('.join(omnicpp#ns#CurrentContexts()
                \ + omnicpp#ns#LocalUsingDirectives()
                \ + omnicpp#ns#GlobalUsingDirectives(), '\|').'\)::'.a:base.'\[^:]\*\$'
    for item in taglist(tagQuery)
        if s:IsVisible(item.filename)
            let matches += [split(item.name, '::')[-1]]
        endif
    endfor

    "Global context
    for item in taglist('\V\C\^'.a:base.'\[^:]\*\$')
        " Check any 'namespace' or 'class' fields are already included
        " in the item's name
        if s:IsVisible(item.filename)
                    \ && match(a:base, get(item,'namespace','')) >= 0
                    \ && match(a:base, get(item,'class','')) >= 0
            let matches += [split(item.name, '::')[-1]]
        endif
    endfor

    return matches
endfunc


"{{{1 Auxiliary

" Used in the first invocation of Main() to find the base start col
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

func! s:IsVisible(path)
    " Relative paths in tag files are resolved based on the current
    " working directory
    let path = a:path[0] == '/' ? a:path : getcwd().'/'.a:path
    return path == expand('%:p') || index(s:includes, path) >= 0
endfunc

" vim: fdm=marker
