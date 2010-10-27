" Author: Bassam JABBOUR
" Description: Buffer and file parsing routines. File parsing is backed
" up by a cache; when asked for a file, it will retrieve it from the
" cache if it exists and is up-to-date, else it will parse it anew.
" Currently, we search for includes and using-instructions.

" === Data =============================================================

" Keys are complete filenames; for every entry, store its modification
" time ('ftime'), and the parsed data ('matches').
let s:cache = {}

" The data to grep, ORed.
let g:omnicpp#parse#reData = '^\s*'.g:omnicpp#include#reInclude.'\|'.g:omnicpp#using#reUsing

" === Buffer functions =================================================

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
function! omnicpp#parse#Local(regex)
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
function! omnicpp#parse#Global(regex)
    let origPos = getpos('.')
    " Get out of local block, if any
    call searchpair('{', '', '}', 'brW', 'omnicpp#utils#IsCursorInCommentOrString()')
    let sanitized = s:SanitizeJump([1,0])
    call setpos('.', origPos)
    return s:SequentialMatch(sanitized, a:regex)
endfunc

" === File functions ===================================================

" Grep a regex from a file into the location list, then extract and
" return the matching strings.
"
" @param file Full path to the file to be parsed
" @param regex Regexp to be grepped
" @param ... a non-zero numeric argument stops the search at the
" specified line
"
" @return List of matches; every match is a dictionary with keys:
" - text: the grepped text
" - line: the line number the match appears at in the file
"
func! omnicpp#parse#Grep(file, regex, ...)
    let matches = []
    " Throws an E315 error
    "exe 'silent! lgrep' a:regex a:file
    exe 'noau silent! lvimgrep /'.a:regex.'/gj '.a:file

    for line in getloclist(0)
        if a:0 && a:1 && line.lnum > a:1 | break | endif
        call add(matches, {'text' : matchstr(line.text, a:regex),
                    \ 'line' : line.lnum})
    endfor

    return matches
endfunc

" Parse a single file for includes and using-instructions; if a numeric
" argument is given, parse up to that line. File access is cached,
" except for partial parses.
"
" @param filename File to parse
" @param ... a non-zero numeric argument stops the parsing at the
" specified line
"
" @return see Grep()
"
func! omnicpp#parse#File(filename,...)
    if s:CacheHas(a:filename) && !(a:0 && a:1)
        return s:cache[a:filename].matches
    else
        let matches = omnicpp#parse#Grep(a:filename, g:omnicpp#parse#reData, get(a:000,0,0))
        call s:ParsePost(matches, omnicpp#utils#ParentDir(a:filename))
        if !(a:0 && a:1)
            let s:cache[a:filename] = {'ftime' : getftime(a:filename), 'matches' : matches}
        endif
        return matches
    endif
endfunc

" === Auxiliary ========================================================

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

" Check if an entry exists in the cache and is up-to-date
func! s:CacheHas(filename)
    return has_key(s:cache, a:filename) && s:cache[a:filename].ftime == getftime(a:filename)
endfunc

" Process the grepped data: resolve includes and sanitize
" using-instructions
func! s:ParsePost(matches,pwd)
    for item in a:matches
        let item.text = (item.text[0] == '"' || item.text[0] == '<')
                    \ ? omnicpp#include#Resolve(item.text,a:pwd)
                    \ : omnicpp#using#Sanitize(item.text)
    endfor
    call filter(a:matches, '!empty(v:val.text)')
endfunc
