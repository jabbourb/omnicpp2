" Author: Bassam JABBOUR
" Description: Functions for matching a regex in local and global scopes 


" Search backwards for a master regexp in the local scope, starting at
" the cursor's position; if it is found, match the partial regexes, in
" order, against the corresponding string (see s:GetMatches()).
" If we are in global scope, returns an empty list.
"
" This has two advantages over single regexp matching:
" - it is useful for circumventing *E51* 'too many (' in complicated
"   regexes: the fine grained matching is applied in the sub regexes
"   instead of the master regexp.
" - we can extract multiple sub patterns in a single pass (don't know if
"   that can be done in a single regexp)
"
" @param reMaster the master regexp, used to find the whole statement in
" the local scope
" @param reSubs a list of sub regexes to be matched against the
" whole statement found using the master regexp
" @param ... an optional non-null argument stops the search after the
" first match is found (the match that takes precedence)
"
" @return List of matches; every match is a list of strings, each
" corresponding to a sub-regex match
"
function! omnicpp#scope#MatchLocal(reMaster, reSubs, ...)
    let matches = []
    " Start of local scope
    let localStop = searchpair('{', '', '}', 'bnr')

    " If we are in global scope, do nothing
    if localStop
        let origPos = getpos('.')

        " Search backwards for the main regexp
        while search(a:reMaster, 'bWe', localStop)
            " Skip if we are in a comment or string
            if omnicpp#utils#IsCursorInCommentOrString() | continue | endif

            " Look up the end of the current local scope, and ensure it
            " encompasses the position where the search started.
            " ex1 of otherwise false positive looking for namespaces:
            " {
            "   { using namespace std;}
            "   ...
            "   $cursor_position
            " }
            " ex2 of otherwise false positive looking for namespaces:
            " using namespace std; {
            "   ...
            "   $cursor_position
            " }
            let scopeEnd = searchpairpos('{', '', '}', 'n')
            if !(scopeEnd[0] >= origPos[1] && scopeEnd[1] >= origPos[2]) | continue | endif

            " Extract string between start and end of match, then apply
            " regexes
            let matchEnd = getpos('.')[1:2]
            let matchStart = searchpos(a:reMaster, 'bW')
            let matches += [s:GetSubMatches(omnicpp#utils#GetCode(matchStart, matchEnd), a:reSubs)]

            if a:0 && a:1 | break | endif
        endwhile

        call setpos('.', origPos)
    endif

    return matches
endfunc


" Search backwards for a master regexp in the global scope, starting at
" the cursor's position; if it is found, match the partial regexes, in
" order, against the corresponding string (see
" omnicpp#scope#GetLocal()).
"
" @param reMaster the master regexp, used to find the whole statement in
" the local scope
" @param reSubs a list of sub regexes to be matched against the
" whole statement found using the master regexp
" @param ... an optional non-null argument stops the search after the
" first match is found (the match that takes precedence)
"
" @return List of matches; every match is a list of strings, each
" corresponding to a sub-regex match
"
" TODO: parse includes too
function! omnicpp#scope#MatchGlobal(reMaster, reSubs, ...)
    let matches = []
    let originalPos = getpos('.')

    while search(a:reMaster, 'bWe')
        " If we are inside a block, get out of it and continue the loop
        if searchpair('{', '', '}', 'br') | continue | endif

        if omnicpp#utils#IsCursorInCommentOrString() | continue | endif

        let matchEnd = getpos('.')[1:2]
        let matchStart = searchpos(a:reMaster, 'bW')
        let matches += [s:GetSubMatches(omnicpp#utils#GetCode(matchStart, matchEnd), a:reSubs)]

        if a:0 && a:1 | break | endif
    endwhile

    call setpos('.', originalPos)
    return matches
endfunc


" Match a list of regexes, in order, against a string. Each match starts
" where the previous one has ended, and yields a string (a splice at the
" match boundaries) that is appended to the results after it has been
" purged from spaces.
"
" @param str the string to match the regexes against
" @param reSubs a list of regexes to match sequentially against the
" argument string
"
" @return List of strings
"
function! s:GetSubMatches(str, reSubs)
    let matches = []
    let matchEnd = 0
    for regex in a:reSubs
        let matchStart = match(a:str, regex, matchEnd)
        if matchStart == -1 | continue | endif

        let matchEnd = matchend(a:str, regex, matchEnd)
        call add(matches, substitute(a:str[matchStart : matchEnd-1], '\s', '', 'g'))
    endfor
    return matches
endfunc
