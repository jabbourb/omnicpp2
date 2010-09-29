" Author: Bassam JABBOUR
" Description: Routines for resolving and working with include files

" The regexp used to match includes
let s:reInclude = '\C^\s*#\s*include\s*\zs[<"].\{1,}[>"]'

" List #include directives in the current local scope up to the cursor's
" position.
function! omnicpp#include#LocalIncludes()
    return omnicpp#scope#MatchLocal(s:reInclude)
endfunc

" List #include directives in the global scope up to the cursor's
" position.
function! omnicpp#include#GlobalIncludes()
    return omnicpp#scope#MatchGlobal(s:reInclude)
endfunc

" List all includes visible from the current buffer. We first look up
" local and global includes, then recursively 'grep' those, building up
" a list of visited files as we go.
"
" @return list of filenames, including the current buffer
"
func! omnicpp#include#AllIncludes()
    let includes = omnicpp#include#LocalIncludes()
    let includes += omnicpp#include#GlobalIncludes()

    " Add current file to parsed includes
    let visited = [expand('%:p')]
    call s:ParseIncludes(includes, expand('%:p:h'), visited)
    return visited
endfunc

" Recursive auxiliary function: given a list of includes, look up the
" matching files in the current directory and/or the path; for every
" file found, append it to the list of visited files, then recursively
" parse it with the current directory set to that of the parent file.
"
" @param includes list of includes ['"inc1.h"', '<inc2.h>']
" @param currentDir the directory where to look up quoted includes
" @param visited the list of visited files
"
" @return nothing; modifies the list of visited files
"
func! s:ParseIncludes(includes, currentDir, visited)
    for inc in a:includes
       if index(a:visited, inc) == -1
           let file = ''
           " Search current directory for quoted includes
           if inc[0] == '"'
               let file = get(split(globpath(a:currentDir, inc[1:-2],'\n')), 0, '')
           endif
           " Search path for all includes
           if empty(file)
               let file = get(split(globpath(&path, inc[1:-2]),'\n'), 0, '')
           endif

           " We were successful in finding the file
           if !empty(file)
               " Add the file to the list of parsed includes
               call add(a:visited, file)
               " Grep includes
               let found = s:ParseFile(file)
               " Recursively parse them, changing current directory to
               " that of the parent file
               call s:ParseIncludes(found, '/'.join(split(file,'/')[:-2],'/'), a:visited)
           endif
       endif
   endfor
endfunc

" Grep includes from the given file into the location list, then extract
" the matching strings.
"
" @param file the full path to the file to be parsed
" @return list of includes
"
func! s:ParseFile(file)
    let includes = []
    exe 'noau silent! lvimgrep /'.s:reInclude.'/gj '.a:file
    let loclist = getloclist(0)
    for inc in loclist
        let line = inc.text
        let includes += [matchstr(line, s:reInclude)]
    endfor
    return includes
endfunc
