" The omnifunc method
function! omnicpp#complete#Main(findstart, base)
    if a:findstart
        " We need to set s:mayComplete to 1 if completion is possible
        " for the second call
        if !omnicpp#utils#IsCursorInCommentOrString()
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

    return [a:base]
endfunc


" Used in the first invocation of Main() to find the base start col
"
" @return the base start col, or -1 if we no completion is possible
"
function! s:FindStartOfCompletion()
    let tokens = omnicpp#tokenizer#TokenizeCurrentInstruction()

    if !empty(tokens)
        if index(['keyword', 'identifier'], tokens[-1].type) >= 0
            return col('.') - len(tokens[-1].text) -1
        elseif tokens[-1].type == 'operator'
            return col('.') -1
        endif
    endif

    return -1
endfunc

