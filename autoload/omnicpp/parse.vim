" Author: Bassam JABBOUR
" Description: A file parser backed by a cache. When asked for a file,
" it will retrieve it from the cache if it exists and is up-to-date,
" else it will parse it anew. Currently, files are parsed for includes
" and using-declarations.

" Keys are complete filenames; for every entry, store its modification
" time, and the parsed data.
let s:cache = {}

let s:reData = g:omnicpp#include#reInclude.'\|'.g:omnicpp#context#reUsing

" Grep a regex from a file into the location list, then extract and
" return the matching strings.
"
" @param file Full path to the file to be parsed
" @param regex Regexp to be grepped
" @param ... a non-zero numeric argument stops the search at the
" specified line
"
" @return List of matches
"
func! omnicpp#parse#Grep(file, regex, ...)
    let matches = []
    " Throws an E315 error
    "exe 'silent! lgrep' a:regex a:file
    exe 'noau silent! lvimgrep /'.a:regex.'/gj '.a:file
    for line in getloclist(0)
        if a:0 && a:1 && line.lnum > a:1 | break | endif
        let matches += [matchstr(line.text, a:regex)]
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
" @return List of includes and using-instructions, ordered
"
func! omnicpp#parse#File(filename,...)
    if s:CacheHas(a:filename) && !a:0
        return s:cache[a:filename].data
    else
        let data = omnicpp#parse#Grep(a:filename, s:reData, get(a:000,0,0))
        let data = s:ParsePost(data, omnicpp#utils#ParentDir(a:filename))
        " Don't cache partial parses
        if !a:0
            let s:cache[a:filename] = {'ftime' : getftime(a:filename),
                        \ 'data' : data}
        endif
        return data
    endif
endfunc

" Recursively parse a file for includes and using-instructions.
" Internally, we build a graph around file dependencies, then extract
" the data by walking through that graph. Includes appear only the first
" time, while using-instructions are not filtered.
"
" @param filename File to parse
" @param ... a non-zero numeric argument stops parsing the main file at
" the specified line
"
" @return List of includes and using-instructions, ordered
"
func! omnicpp#parse#Recursive(filename,...)
    let graph = omnicpp#graph#Graph(a:filename)
    call graph.root.addChildren(omnicpp#parse#File(graph.root.data, get(a:000,0,0)))
    let visited = [a:filename]

    while !empty(graph.next())
        let data = graph.current.data
        " Parse new includes and add their content to the graph
        if data[0] == '/'
            if index(visited, data) == -1
                call graph.current.addChildren(omnicpp#parse#File(data))
                call add(visited, data)
            endif
        else
            call add(visited, data)
        endif
    endwhile

    return visited
endfunc


" === Auxiliary ========================================================

" Check if an entry exists in the cache and is up-to-date
func! s:CacheHas(filename)
    return has_key(s:cache, a:filename) && s:cache[a:filename].ftime == getftime(a:filename)
endfunc

" Process the grepped data: resolve includes and sanitize
" using-instructions
func! s:ParsePost(data,pwd)
    let results = []

    for item in a:data
        if item[0] == '"' || item[0] == '<'
            " Resolve includes
            let resolved = omnicpp#include#Resolve(item,a:pwd)
            if !empty(resolved)
                call add(results, resolved)
            endif
        else
            " Sanitize using-instructions
            call add(results, omnicpp#context#Sanitize(item))
        endif
    endfor

    return results
endfunc
