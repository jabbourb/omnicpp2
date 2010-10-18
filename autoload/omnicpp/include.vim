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
" @param file Full path of the file to be parsed
" @return List of includes, expanded path
"
func! omnicpp#include#Parse(file, ...)
    if s:cache.has(a:file)
        return s:cache.get(a:file)
    endif

    let includes = omnicpp#utils#VGrep(a:file, s:reInclude, get(a:000,0,0))
    let pwd = '/'.join(split(a:file,'/')[:-2],'/')
    call s:ResolveIncludes(includes, pwd)
    " Don't update the cache for partial parses
    if !a:0 | call s:cache.put(a:file, includes) | endif

    return includes
endfunc

" Parse a file (or list of files) recursively. The behavior differs
" between a single file and a list; the former is parsed up to a certain
" line (if specified) and is not included in the results, whereas in the
" latter case input files are parsed completely (ignoring optional
" arguments), and are included in the results.
"
" @param entry path of the file to be parsed, or list of paths
" @param ... when given a single file, a non-zero numeric argument stops
" parsing that file at the specified line
" @return List of includes visible from the input file, expanded
" (caveat: see description)
"
func! omnicpp#include#ParseRecursive(entry, ...)
    " Unparsed includes
    let includes = type(a:entry) == type('')
                \ ? omnicpp#include#Parse(a:entry, get(a:000,0,0))
                \ : copy(a:entry)
    " Resolved includes
    let visited = []

    while !empty(includes)
        let inc = remove(includes,-1)
        call add(visited, inc)

        for found in omnicpp#include#Parse(inc)
            " Check for duplicates
            if index(visited, found) == -1
                call add(includes, found)
            endif
        endfor
    endwhile

    return visited
endfunc

" List all includes visible from the current buffer up to the cursor's
" position, by recursively parsing local and global includes before the
" cursor.
"
" @return List of includes, expanded
"
func! omnicpp#include#CurrentBuffer()
    " We cannot cache those, since the cursor's position changes
    let includes = omnicpp#include#LocalIncludes() + omnicpp#include#GlobalIncludes()
    call s:ResolveIncludes(includes, expand('%:p:h'))
    return omnicpp#include#ParseRecursive(includes)
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
