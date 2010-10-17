" Author: Bassam JABBOUR
" Description: Routines for resolving and working with include files

" === Data =============================================================

" The regexp used to match includes
let s:reInclude = '\C#\s*include\s\+\zs[<"].\{-1,}[>"]'
" Cache, for every parsed file, the list of includes found
let s:cache = omnicpp#cache#Create()

" === Functions ========================================================

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

" Grep includes from a file, then resolve them relatively to the file's
" parent directory (non-recursive). If a cache entry is present and
" up-to-date, it is used instead of parsing the file, else the cache is
" updated.
"
" @param file Full path to the file to be parsed
" @return List of includes, expanded path
"
func! omnicpp#include#Parse(file)
    if s:cache.has(a:file)
        return s:cache.get(a:file)
    endif

    let includes = omnicpp#utils#VGrep(a:file, s:reInclude)
    let pwd = '/'.join(split(a:file,'/')[:-2],'/')
    call s:ResolveIncludes(includes, pwd)
    call s:cache.put(a:file, includes)

    return includes
endfunc

" List all includes visible from the current buffer. We start by
" building a list of local and global includes; then we parse every
" entry for additional includes, add those to the list, and loop till
" all the includes have been parsed.
"
" At the end, the list of visited files is returned (every include found
" and parsed is listed once)
"
" @return list of filenames, including the current buffer
"
func! omnicpp#include#AllIncludes()
    let curBuf = expand('%:p')

    if s:cache.has(curBuf)
        let includes = s:cache.get(curBuf)
    else
        " The includes to be parsed
        let includes = omnicpp#include#LocalIncludes()
        let includes += omnicpp#include#GlobalIncludes()
        " Resolve all includes
        call s:ResolveIncludes(includes, expand('%:p:h'))

        call s:cache.put(curBuf, includes)
    endif

    " Add current filename to parsed files in case it is included in one
    " of the headers
    let visited = [curBuf]

    while !empty(includes)
        let inc = remove(includes,-1)
        " Check for duplicates
        if index(visited, inc) >= 0 | continue | endif

        call add(visited, inc)
        let includes += omnicpp#include#Parse(inc)
    endwhile

    " Remove current buffer
    call remove(visited, 0)
    return visited
endfunc

" === Auxiliary ========================================================

" Resolve the filename referenced by an include directive by first
" searching the current directory (for quoted includes), then the &path
" variable.
"
" @param include the include name to resolve
" @param currentDir the current directory (for resolving quoted
" includes)
" @return the filename string if found, or an empty string
"
func! s:ResolveInclude(include, currentDir)
    let path = ''
    let names = [a:include[1:-2]]

    " Search current directory for quoted includes
    if a:include[0]=='"'
        let path = get(split(globpath(a:currentDir, names[0]),'\n'), 0, '')
    " Extension is optional for bracket includes
    else
        let names += [names[0].'.h', names[0].'.hpp']
    endif

    " Search &path for all includes
    for inc in names
        if empty(path)
            let path = get(split(globpath(&path, inc),'\n'), 0, '')
        else
            break
        endif
    endfor

    return path
endfunc

" Wrapper function around ResolveInclude; resolves all includes in a
" list, and removes empty entries (includes that weren't found)
func! s:ResolveIncludes(includes, currentDir)
    call map(a:includes, 's:ResolveInclude(v:val, a:currentDir)')
    call filter(a:includes, '!empty(v:val)')
endfunc
