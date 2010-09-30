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
" local and global includes; then, for every include, we parse that
" file for includes (if it hasn't been processed already), add those to
" the list of includes, and loop.
"
" At the end, the list of visited files is returned (every include found
" and parsed is listed here)
"
" @return list of filenames, including the current buffer
"
func! omnicpp#include#AllIncludes()
    " The includes to be parsed
    let includes = omnicpp#include#LocalIncludes()
    let includes += omnicpp#include#GlobalIncludes()

    " Add current filename to parsed files
    let visited = [expand('%:p')]

    " Resolve all includes
    let pwd = expand('%:p:h')
    call s:ResolveIncludes(includes, pwd)

    while !empty(includes)
        let inc = remove(includes,-1)
        " Check for duplicates
        if index(visited, inc) >= 0
            continue
        endif
        call add(visited, inc)

        let found = s:ParseFile(inc)
        let pwd = '/'.join(split(inc,'/')[:-2],'/')
        call s:ResolveIncludes(found, pwd)
        " It is ok to have duplicates, only the first one will be parsed
        let includes += found
    endwhile

    return visited
endfunc


" Resolve the filename referenced by an include directive by first
" searching the current directory (for quoted includes), then the path
"
" @param include the include name to resolve
" @param currentDir the current directory (for resolving quoted
" includes)
" @return the filename string if found, or an empty string
"
func! s:ResolveInclude(include, currentDir)
    let path = ''
    " Search current directory for quoted includes
    if a:include[0]=='"'
        let path = get(split(globpath(a:currentDir, a:include[1:-2],'\n')), 0, '')
    endif
    " Search path for all includes
    if empty(path)
        let path = get(split(globpath(&path, a:include[1:-2]),'\n'), 0, '')
    endif
    return path
endfunc

" Wrapper function around ResolveInclude; resolves all includes in a
" list, and removes empty entries (includes that weren't found)
func! s:ResolveIncludes(includes, currentDir)
    call map(a:includes, 's:ResolveInclude(v:val, a:currentDir)')
    call filter(a:includes, '!empty(v:val)')
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
