" Author: Bassam Jabbour
" Description: Utility functions for OmniCpp2


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
func! omnicpp#utils#ExtractCode(startPos, endPos, ...)
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

" Extract the current instruction up to the cursor's position
" (excluded). Instruction boundaries matching isn't perfect, and will
" sometimes extract more code than intended.
"
" This is a convenience wrapper around ExtractCode().
"
func! omnicpp#utils#ExtractInstruction()
    let origPos = getpos('.')
    while searchpos('\v[;{}#]|%^', 'bW') != [1,1]
        if !omnicpp#utils#IsCursorInCommentOrString() | break | endif
    endwhile
    let code = omnicpp#utils#ExtractCode (getpos('.')[1:2], origPos[1:2], 1)
    call setpos('.', origPos)
    return code
endfunc

" Scan a string backwards, and find the opening element of an
" (open,close) pair encompassing the end of the string. This is similar
" to searchpair() (but for strings).
"
" @param string the string to scan
" @param open the opening character
" @param close the closing character
"
" @return the index of the opening character, -1 if none
"
func! omnicpp#utils#SearchPairBack(string, open, close)
    let counter = 0
    for idx in reverse(range(len(a:string)))
        if a:string[idx] == a:open
            if counter==0
                return idx
            else
                let counter -= 1
            endif
        elseif a:string[idx] == a:close
            let counter += 1
        endif
    endfor
    return -1
endfunc

" Check if the cursor is in a comment or string
"
" @param ... if an non-null argument is given, move the cursor one
" position backward
"
func! omnicpp#utils#IsCursorInCommentOrString(...)
    let col = a:0 && a:1 ? col('.')-1 : col('.')
    return match(synIDattr(synID(line("."), col, 1), "name"), '\C\<cComment\|\<cCppString\|\<cString')>=0
endfunc

func! omnicpp#utils#VGrep(file, regex)
    let matches = []
    exe 'noau silent! lvimgrep /'.a:regex.'/gj '.a:file
    for line in getloclist(0)
        let matches += [matchstr(line.text, a:regex)]
    endfor
    return matches
endfunc


" Concatenate lines ending with a backslash
func! s:JoinBackslash(lines)
    let joined = []
    let acc = ''
    for line in a:lines
        let joinLine = matchstr(line, '.*\ze\\\s*')
        if !empty(joinLine)
            let acc .= ' '.joinLine
        else
            let acc .= ' '.line
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
    let sanitized = ''

    let blockComment = 0
    for line in a:lines
        " If we are in a block comment started on a previous line, check
        " for its end
        if blockComment
            let commentEnd = matchend(line, '\*/')
            " Block comment ends on this line
            if commentEnd != -1
                let line = strpart(line, commentEnd)
                let blockComment = 0
                " Whole line is inside comment, skip it
            else
                continue
            endif
        endif

        " Search for strings, line comments and block comments starting on
        " the current line, with strings not in an include statement, and
        " delete them. We keep markers around block comments to detect
        " wether they were closed on the same line.
        let line = substitute(line, '\v(/\*\zs.{-}\ze(\*/|$))'.'|'.'((#\s*include\s+)@<!"\zs.{-}\ze")'.'|'.'//.*', '', 'g')
        " Remove block markers when comments are closed on the same line
        let line = substitute(line, '\V/**/', '', 'g')
        " An orphan '/*' marker indicates a block comment that is still open
        if match(line, '/\*') != -1
            let blockComment = 1
            let line = substitute(line, '/\*', '', '')
        endif

        let sanitized .= ' '.line
    endfor

    return sanitized
endfunc
