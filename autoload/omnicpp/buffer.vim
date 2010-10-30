" Author: Bassam JABBOUR
" Description: Functions for dealing with text extraction from a buffer


" Get the code between two buffer positions after sanitizing it.
" We assume that startPos is NOT inside a comment or string.
"
" @param startPos the starting buffer position [line, col] for the
" extracted code
" @param endPos the ending buffer position
" @param ... by default, the range is inclusive; a non-null optional
" argument makes it exclusive
"
" @return An object representing the extracted text which, when searched
" for a regexp, will return the results in a format similar to
" parse#Grep()
" - text : the extracted text, sanitized and concatenated into a single
"   string
" - boundaries : List of 2-elements lists, each mapping a line number to
"   an index in the 'text' string
" - line() : see buffer#NLLine()
" - match() : see buffer#NLMatch()
"
func! omnicpp#buffer#ExtractCode(startPos, endPos, ...)
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

    let lnum = []
    for idx in range(len(lines))
        call add(lnum, [lines[idx], a:startPos[0]+idx])
    endfor

    return s:NumberedLines(s:CommentsAndStrings(s:JoinBackslash(lnum)))
endfunc

" Extract the current instruction up to the cursor's position
" (excluded). Instruction boundaries matching isn't perfect, and will
" sometimes extract more code than intended.
"
" This is a convenience wrapper around ExtractCode().
"
func! omnicpp#buffer#ExtractInstruction()
    let origPos = getpos('.')
    while searchpos('\v[;{}#]|%^', 'bW') != [1,1]
        if !omnicpp#buffer#IsCursorInCommentOrString() | break | endif
    endwhile
    let code = omnicpp#buffer#ExtractCode (getpos('.')[1:2], origPos[1:2], 1)
    call setpos('.', origPos)
    return code
endfunc

" Check if the cursor is in a comment or string
"
" @param ... if an non-null argument is given, move the cursor one
" position backward
"
func! omnicpp#buffer#IsCursorInCommentOrString(...)
    let col = a:0 && a:1 ? col('.')-1 : col('.')
    return match(synIDattr(synID(line("."), col, 1), "name"), '\C\<cComment\|\<cCppString\|\<cString')>=0
endfunc

" === Auxiliary ========================================================

" Concatenate lines ending with a backslash
func! s:JoinBackslash(lnum)
    let joined = []
    let joinPrev = 0

    for line in a:lnum
        if match(line[0], '\\\s*$') >= 0
            let joinNext = 1
            let line[0] = matchstr(line[0], '.*\ze\\\s*$')
        else
            let joinNext = 0
        endif

        if joinPrev
            let joined[-1][0] .= ' '.line[0]
        else
            call add(joined, line)
        endif

        let joinPrev = joinNext
    endfor

    return joined
endfunc

" Empty strings and remove block/line comments.
" Warning: Unclosed strings will result in a weird behaviour!
"
" @param lines text lines as output by JoinBackslash()
" @return a single string
"
func! s:CommentsAndStrings(lnum)
    let sanitized = []

    let blockComment = 0
    for line in a:lnum
        " If we are in a block comment started on a previous line, check
        " for its end
        if blockComment
            let commentEnd = matchend(line[0], '\*/')
            if commentEnd != -1
                " Block comment ends on this line
                let line[0] = strpart(line[0], commentEnd)
                let blockComment = 0
            else
                " Whole line is inside comment, skip it
                continue
            endif
        endif

        " Search for strings, line comments and block comments starting on
        " the current line, with strings not in an include statement, and
        " delete them. We keep markers around block comments to detect
        " wether they were closed on the same line.
        let line[0] = substitute(line[0], '\v(/\*\zs.{-}\ze(\*/|$))'.'|'.'((#\s*include\s+)@<!"\zs.{-}\ze")'.'|'.'//.*', '', 'g')
        " Remove block markers when comments are closed on the same line
        let line[0] = substitute(line[0], '\V/**/', '', 'g')
        " An orphan '/*' marker indicates a block comment that is still open
        if match(line[0], '/\*') >= 0
            let blockComment = 1
            let line[0] = substitute(line[0], '/\*', '', '')
        endif

        if !empty(line[0])
            call add(sanitized, line)
        endif
    endfor

    return sanitized
endfunc

" Build an object out of numbered lines that can be used to look up a
" regexp in a fashion similar to parse#Grep(). Internally, all text is
" concatenated to allow searches spanning multiple lines.
"
" @param lnum List of numbered lines, each item being a 2-elements list
" [text, line]
" @return see buffer#ExtractCode()
"
func! s:NumberedLines(lnum)
    let text = ''
    let boundaries = []

    for line in a:lnum
        let text .= ' '.line[0]
        call add(boundaries, [line[1], len(text)])
    endfor

    return { 'text' : text, 'boundaries' : boundaries,
                \ 'line' : function("omnicpp#buffer#NLLine"),
                \ 'match' : function("omnicpp#buffer#NLMatch")}
endfunc

" Given a string index, return the line the corresponding character
" appears in.
func! omnicpp#buffer#NLLine(idx) dict
    for bound in self.boundaries
        if bound[1] >= a:idx
            return bound[0]
        endif
    endfor
    return 0
endfunc

" Match against a regexp sequentially, each match starting where the
" previous match ended.
func! omnicpp#buffer#NLMatch(regex) dict
    let matches = []
    " Head pointer
    let head = 0
    while 1
        let matchStart = match(self.text, a:regex, head)
        if matchStart == -1 | break | endif
        let matchEnd = matchend(self.text, a:regex, head)

        let mm = {'text' : strpart(self.text, matchStart, matchEnd-matchStart),
                    \ 'line' : self.line(matchStart)}
        call add(matches, mm)
        let head = matchEnd
    endwhile
    return matches
endfunc
