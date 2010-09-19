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
" @return the code string between startPos and endPos
"
function! omnicpp#utils#GetCode(startPos, endPos, ...)
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

    return omnicpp#utils#Sanitize(lines)
endfunc


" Sanitize lines, removing comments and emptying strings
"
" @param lines the code lines to process (list of strings)
" @return result as a single string
"
function! omnicpp#utils#Sanitize(lines)
    " Remove line comments
    call map(a:lines, "substitute(v:val, '//.*', '', 'g')")

    let single = join(a:lines, ' ')
    " Empty strings
    let single = substitute(single, '"[^"]*"', '""', 'g')
    " C style comments; we don't have to worry about being in a string
    " or line comment
    let single = substitute(single, '\M/*\_.\{-}*/', '', 'g')

    return single
endfunc


" Check if the cursor is in a comment or string
" If an non-null argument is given, move the cursor one position
" backward
function! omnicpp#utils#IsCursorInCommentOrString(...)
    let col = a:0 && a:1 ? col('.')-1 : col('.')
    return match(synIDattr(synID(line("."), col, 1), "name"), '\C\<cComment\|\<cCppString\|\<cIncluded')>=0
endfunc


" Assuming the cursor is on the last character of an instruction, match
" up to its beginning and return the corresponding string, making sure
" we are not in a comment or string and removing spaces.
"
" This is used when parsing the current buffer backwards.
"
" @param regex the regex used to match the namespace instruction
" @return the extracted string in a single element list, or an empty
" list
"
function! omnicpp#utils#GetInstructionBack(regex)
    if omnicpp#utils#IsCursorInCommentOrString()
        return []
    endif

    let matchEnd = getpos('.')[1:2]
    let matchStart = searchpos(a:regex, 'bW')
    return [substitute(omnicpp#utils#GetCode(matchStart, matchEnd), '\s', '', 'g')]
endfunc
