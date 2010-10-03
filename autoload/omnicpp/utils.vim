" Description: Utility functions for OmniCpp2
" Author: Bassam Jabbour


" Get the code between two buffer positions after sanitizing it.
" We assume that startPos is NOT inside a comment or string.
"
" @param startPos the starting buffer position [line, col] for the
" extracted code
" @param endPos the ending buffer position
" @param ... by default, the range is inclusive; a non-null optional
" argument makes it exclusive
"
" @return the code string between startPos and endPos
"
function! omnicpp#utils#ExtractCode(startPos, endPos, ...)
    if a:0 && a:1
        let startPos = a:startPos[1]
        let endPos = a:endPos[1]-1
    else
        let startPos = a:startPos[1]-1
        let endPos = a:endPos[1]
    endif
    let lines = getline(a:startPos[0], a:endPos[0])

    " Trim first and last line to selected columns
    let startByte = byteidx(lines[0], startPos)
    let endByte = byteidx(lines[-1], endPos)
    if len(lines) == 1
        " We need to do it in one pass else indexes are invalidated
        let lines[0] = strpart(lines[0], startByte, endByte-startByte)
    else
        let lines[0] = strpart(lines[0], startByte)
        let lines[-1] = strpart(lines[-1], 0, endByte)
    endif

    return s:CommentsAndStrings(s:JoinBackslash(lines))
endfunc

" Concatenate lines ending with a backslash
func! s:JoinBackslash(lines)
    let joined = []
    let acc = ''
    for line in a:lines
        let joinLine = matchstr(line, '.*\ze\\\s*')
        if !empty(joinLine)
            let acc = acc.' '.joinLine
        else
            let acc = acc.' '.line
            call add(joined, acc)
            let acc = ''
        endif
    endfor
    if !empty(acc) | call add(joined, acc) | endif
    return joined
endfunc

" Empty strings and remove block/line comments.
" Warning: Unclosed strings will result in a weird behaviour!
"
" @param lines text lines as output by JoinBackslash()
" @return a single string
"
func! s:CommentsAndStrings(lines)
    " Search for strings and line comments not inside a block comment,
    " with strings not in an include statement, and delete them
    call map(a:lines, 'substitute(v:val, "\\v((/\\*.*)@<!|(/\\*.{-}\\*/.*)@<=)((#include\\s+)@<!\"\\zs.{-}\\ze\"|//.*)", "", "g")')
    " Delete block comments after concatenating lines
    return substitute(join(a:lines,' '), '\M/*\.\{-}*/', '', 'g')
endfunc


" Check if the cursor is in a comment or string
"
" @param ... if an non-null argument is given, move the cursor one
" position backward
function! omnicpp#utils#IsCursorInCommentOrString(...)
    let col = a:0 && a:1 ? col('.')-1 : col('.')
    return match(synIDattr(synID(line("."), col, 1), "name"), '\C\<cComment\|\<cCppString\|\<cString')>=0
endfunc
