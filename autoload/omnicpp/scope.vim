" Author: Bassam JABBOUR
" Description: Functions for matching a regex in local and global scopes 


" Builds a list of matches matching a given regex in the current
" local scope up to the cursor's position; the strings are extracted by
" matching between the beginning and end of the regex.  If we are in
" global scope, returns an empty list.
"
" @param regex the regex used for matching matches
" @param ... an optional non-null argument stops the search after the
" first match is found (the match that takes precedence)
"
" @return List of matched strings
"
function! omnicpp#scope#MatchLocal(regex, ...)
    let matches = []
    " Start of local scope
    let localStop = searchpair('{', '', '}', 'bnr')

    " If we are in global scope, do nothing
    if localStop
        let origPos = getpos('.')

        " Search backwards and put cursor at end of match
        while search(a:regex, 'bWe', localStop)
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
            if scopeEnd[0] >= origPos[1] && scopeEnd[1] >= origPos[2]
                let matches += s:GetInstructionBack(a:regex)
                if a:0 && a:1 | break | endif
            endif
        endwhile

        call setpos('.', origPos)
    endif

    return matches
endfunc


" Builds a list of instructions matching a regex in the global scope of
" the current buffer up to the cursor's position; the strings are
" extracted by matching between the beginning and end of the regex.
"
" @param regex the regex used for matching matches
" @param ... an optional non-null argument stops the search after the
" first match is found (the match that takes precedence)
"
" @return List of matched strings
"
" TODO: parse includes too
function! omnicpp#scope#MatchGlobal(regex, ...)
    let matches = []
    let originalPos = getpos('.')
    while search(a:regex, 'bWe')
        " If we are inside a block, get out of it and continue the loop,
        " else add the match
        if !searchpair('{', '', '}', 'br')
            let matches += s:GetInstructionBack(a:regex)
            if a:0 && a:1 | break | endif
        endif
    endwhile
    call setpos('.', originalPos)
    return matches
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
function! s:GetInstructionBack(regex)
    if omnicpp#utils#IsCursorInCommentOrString()
        return []
    endif

    let matchEnd = getpos('.')[1:2]
    let matchStart = searchpos(a:regex, 'bW')
    return [omnicpp#utils#ExtractCode(matchStart, matchEnd)]
endfunc
