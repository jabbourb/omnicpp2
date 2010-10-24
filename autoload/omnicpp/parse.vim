" Author: Bassam JABBOUR
" Description: A file parser backed by a cache. When asked for a file,
" it will retrieve it from the cache if it exists and is up-to-date,
" else it will parse it anew. Currently, files are parsed for includes
" and using-declarations.

" Keys are complete filenames; for every entry, store its modification
" time ('ftime'), and the parsed data ('matches').
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
" @return List of includes and using-instructions, ordered
"
func! omnicpp#parse#File(filename,...)
    if s:CacheHas(a:filename) && !(a:0 && a:1)
        return s:cache[a:filename].matches
    else
        let matches = omnicpp#parse#Grep(a:filename, s:reData, get(a:000,0,0))
        call s:ParsePost(matches, omnicpp#utils#ParentDir(a:filename))
        if !(a:0 && a:1)
            let s:cache[a:filename] = {'ftime' : getftime(a:filename), 'matches' : matches}
        endif
        return matches
    endif
endfunc

" Recursively parse a file for includes and using-instructions.
" Internally, we build a graph around file dependencies, then extract
" the data by walking through that graph. Includes appear only the first
" time, while using-instructions are neither filtered, nor resolved.
"
" @param filename File to parse
" @param ... a non-zero numeric argument stops parsing the main file at
" the specified line
"
" @return Dictionary with 2 entries:
" - using: List of objects representing using-instructions, with fields:
"   - text: Text of the using-instruction
"   - complete: List of includes that are completely visible at the
"     instruction's location, as well as preceding using-instructions
"   - partial: List of file objects as returned by Grep(); every file is
"     visible up to the 'line' field. This is used for looking up
"     visible declarations when resolving using-instructions.
" - include: List of all includes, recursive, excluding the input file
"
func! omnicpp#parse#Recursive(filename,...)
    " List of using-instructions
    let usingL = []

    let graph = omnicpp#graph#Graph(a:filename)
    call graph.root.addChildren(omnicpp#parse#File(graph.root.text, get(a:000,0,0)))

    while !empty(graph.next())
        let text = graph.current.text
        " Parse new includes and add their content to the graph
        if text[0] == '/'
            call graph.current.addChildren(omnicpp#parse#File(text))
        else
            let using = {}
            let using.text = text
            let using.complete = copy(graph.complete)
            let using.partial = graph.current.path
            call add(usingL, using)
        endif
    endwhile

    " Remove root file from list of includes
    return {'using' : usingL, 'include' : filter(graph.complete, 'v:val[0]=="/"')[:-2]}
endfunc

" === Auxiliary ========================================================

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
                    \ : omnicpp#context#Sanitize(item.text)
    endfor
    call filter(a:matches, '!empty(v:val.text)')
endfunc
