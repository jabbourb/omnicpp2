" Author: Bassam JABBOUR
" Description: A file parser backed by a cache. When asked for a file,
" it will retrieve it from the cache if it exists and is up-to-date,
" else it will parse it anew. Currently, files are parsed for includes
" and using-declarations.

" Keys are complete filenames; for every entry, store its modification
" time, and the parsed data.
let s:cache = {}

let s:reData = g:omnicpp#include#reInclude.'\|'.g:omnicpp#context#reUsing

func! omnicpp#parse#File(filename,...)
    if s:CacheHas(a:filename) && !a:0
        return s:cache[a:filename].data
    else
        let data = omnicpp#utils#Grep(a:filename, s:reData, get(a:000,0,0))
        let data = s:ParsePost(data, omnicpp#utils#ParentDir(a:filename))
        " Don't cache partial parses
        if !a:0
            let s:cache[a:filename] = {'ftime' : getftime(a:filename),
                    \ 'data' : data}
        endif
        return data
    endif
endfunc

func! s:CacheHas(filename)
    return has_key(s:cache, a:filename) && s:cache[a:filename].ftime == getftime(a:filename)
endfunc

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
