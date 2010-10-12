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

    return omnicpp#complete#Vars(a:base)
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

    let incs = omnicpp#include#AllIncludes()

    " Using directives and any context visible at the cursor's position.
    " We want the variable name to be the last part of the full
    " qualified name.
    let tagQuery = '\V\C\^\('.join(omnicpp#ns#CurrentContexts()
                \ + omnicpp#ns#LocalUsingDirectives()
                \ + omnicpp#ns#GlobalUsingDirectives(), '\|').'\)::'.a:base.'\[^:]\*\$'
    for var in taglist(tagQuery)
        " Relative paths in tag files are resolved based on the
        " current working directory
        let filename = s:ResolvePath(var.filename)
        " Only match in files visible from the current buffer
        if filename == expand('%:p') || index(incs, filename) >= 0
            let vars += [split(var.name, '::')[-1]]
        endif
    endfor

    "Global context
    for var in taglist('\V\C\^'.a:base.'\[^:]\*\$')
        let filename = s:ResolvePath(var.filename)
        " Check the match isn't inside a namespace or class (duplicates)
        if (filename == expand('%:p') || index(incs, filename) >= 0)
                    \ && !(has_key(var, 'namespace') || has_key(var, 'class'))
            let vars += [var.name]
        endif
    endfor

    call filter(vars, 'count(vars,v:val)==1')
    return vars
endfunc

"{{{1 Auxiliary

" Used in the first invocation of Main() to find the base start col
"
" @return the base start col, or -1 if no completion is possible
"
function! s:FindStartOfCompletion()
    if !empty(s:tokens)
        if index(['keyword', 'identifier'], s:tokens[-1].type) >= 0
            return col('.') -1 -len(s:tokens[-1].text)
        elseif s:tokens[-1].type == 'operator'
            return col('.') -1
        endif
    endif

    return -1
endfunc

" Resolve a relative path by rooting it at the current directory
func! s:ResolvePath(path)
    return a:path[0] == '/' ? a:path : getcwd().'/'.a:path
endfunc

" vim: fdm=marker
