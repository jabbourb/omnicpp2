" Author: Bassam JABBOUR
" Description: Functions for matching a regex in local and global scopes


" Builds a list of matches against a given regex in the current
" local scope up to the cursor's position; the strings are extracted by
" matching between the beginning and end of the regex.  If we are in
" global scope, returns an empty list.
"
" The parsed code is sanitized first, and all sub-blocks (that do not
" encompass the cursor) are skipped. Since all lines are concatenated,
" regexes cannot use the '^' and '$' characters anymore. Sanitizing the
" code before matching the regexes allows us to not worry about comments
" and the like inside a regexp.
"
" @param regex the regex used for finding matches
" @return list of matched strings
"
function! omnicpp#scope#MatchLocal(regex)
    " Start of local scope
    let localStop = searchpairpos('{', '', '}', 'bnrW', 'omnicpp#utils#IsCursorInCommentOrString()')
    if localStop != [0,0]
        let sanitized = s:SanitizeJump(localStop)
        return s:SequentialMatch(sanitized, a:regex)
    endif
    " If we are in global scope, do nothing
    return []
endfunc


" Builds a list of matches against a regex in the global scope of
" the current buffer up to the cursor's position; the strings are
" extracted by matching between the beginning and end of the regex.
"
" (see MatchLocal() for details)
"
" @param regex the regex used for finding matches
" @return list of matched strings
"
function! omnicpp#scope#MatchGlobal(regex)
    let origPos = getpos('.')
    " Get out of local block, if any
    call searchpair('{', '', '}', 'brW', 'omnicpp#utils#IsCursorInCommentOrString()')
    let sanitized = s:SanitizeJump([1,0])
    call setpos('.', origPos)
    return s:SequentialMatch(sanitized, a:regex)
endfunc


" Extract the code from the current position up to a given position,
" jumping over sub-blocks and removing comments.
"
" @param stopPos the upper limit for the text to extract, exclusive (the
" lower being the current cursor position)
" @return a string built by concatenating useful lines
"
func! s:SanitizeJump(stopPos)
    let origPos = getpos('.')
    let sanitized = ''
    let lastPos = origPos[1:2]

    while search('}', 'bW', a:stopPos[0])
        " If we went beyond the start position, rewind the cursor
        " position and exit
        if getpos('.')[1] == a:stopPos[0] && getpos('.')[2] < a:stopPos[1]
            setpos('.', [0]+lastPos+[0])
            break
        endif

        " Jump over comments and strings
        if omnicpp#utils#IsCursorInCommentOrString() | continue | endif

        let sanitized = omnicpp#utils#ExtractCode(getpos('.')[1:2], lastPos, 1).' '.sanitized
        " Jump over sub-blocks
        if searchpair('{', '', '}', 'bW', 'omnicpp#utils#IsCursorInCommentOrString()')
            let lastPos = getpos('.')[1:2]
        endif
    endwhile

    call setpos('.', origPos)
    " We still need to add the text up to the beginning
    return omnicpp#utils#ExtractCode(a:stopPos, lastPos, 1).' '.sanitized
endfunc

" Match a string against a given regexp sequentially, every search
" starting where the previous match ended.
"
" @return list of matches
"
func! s:SequentialMatch(string, regex)
    let matches = []
    " Head pointer
    let head = 0
    while 1
        let matchStart = match(a:string, a:regex, head)
        if matchStart == -1 | break | endif
        let matchEnd = matchend(a:string, a:regex, head)

        call add(matches, strpart(a:string, matchStart, matchEnd-matchStart))
        let head = matchEnd
    endwhile
    return matches
endfunc
