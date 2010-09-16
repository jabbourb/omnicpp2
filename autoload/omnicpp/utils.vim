" Get the code between two buffer positions, removing comments and
" emptying strings.
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

    " Remove line comments
    call map(lines, "substitute(v:val, '//.*', '', 'g')")

    let single = join(lines, ' ')
    " Empty strings
    let single = substitute(single, '"[^"]*"', '""', 'g')
    " C style comments; we don't have to worry about being in a string
    " or line comment
    let single = substitute(single, '\M/*\_.\{-}*/', '', 'g')

    return single
endfunc