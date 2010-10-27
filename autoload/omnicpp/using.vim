" Author: Bassam JABBOUR
" Description: Functions for looking up and resolving using-instructions

" === Data =============================================================

" The following regexes extract namespaces as XX::YY
" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives; keep leading 'namespace'
" keyword distinguish those from declarations when grepping
let s:reDirective = '\C\v<using>\s+\zs<namespace>\s+\w+(\s*::\s*\w+)*\ze\s*;'

let g:omnicpp#using#reUsing = '^\s*'.s:reDeclaration.'|^\s*'.s:reDirective

" === Functions ========================================================

" Recursively parse a file for using-instructions, also extracting
" includes for resolving them, and preserving instructions order.
" Internally, we build a graph around file dependencies, then extract
" the data by walking through that graph. Includes appear only the first
" time, while using-instructions are not filtered.
"
" @param filename File to parse
" @param ... a non-zero numeric argument stops parsing the main file at
" the specified line
"
" @return List of tag items, one for every resolved using-instruction
"
func! omnicpp#using#FileRecursive(filename,...)
    let graph = omnicpp#graph#Graph(a:filename)
    call graph.root.addChildren(omnicpp#parse#File(graph.root.text, get(a:000,0,0)))
    return s:ResolveInstructions(s:FromGraph(graph))
endfunc

" Sanitize an extracted using-instruction. Spaces are removed, and
" leading 'namespace' keyword in directives is replaced by '::'.
"
" @param context Instruction to sanitize
" @return List of sanitized instructions (using-declarations as XX::YY,
" and using-directives as ::XX::YY)
"
func! omnicpp#using#Sanitize(using)
    return substitute(substitute(a:using, '^namespace\>', '::', ''), '\s\+', '', 'g')
endfunc

" === Auxiliary ========================================================

" Given an initialized graph, walk through that graph, parsing includes
" and extracting using-instructions and their context.
"
" @param graph Graph with the root node parsed
" @return List of objects each corresponding to a using-instruction,
" with fields:
" - text: Text of the using-instruction
" - complete: List of includes that are completely visible at the
"   instruction's location, as well as preceding using-instructions
" - partial: List of file objects as returned by parse#Grep(); every
"   file is visible up to the 'line' field. This is used for looking up
"   visible declarations when resolving using-instructions.
"
func! s:FromGraph(graph)
    let usingL = []

    while !empty(a:graph.next())
        let text = a:graph.current.text
        " Parse new includes and add their content to the a:graph
        if text[0] == '/'
            call a:graph.current.addChildren(omnicpp#parse#File(text))
        else
            let using = {}
            let using.text = text
            let using.complete = copy(a:graph.complete)
            let using.partial = a:graph.current.path
            call add(usingL, using)
        endif
    endwhile

    return usingL
endfunc

" ResolveInstructions using instructions using the context and visibility
" information provided.
"
" @param usingL List of using-objects, as returned by s:FromGraph()
" @return List of tag items, each representing a resolved, unambiguous
" using-instruction
"
func!  s:ResolveInstructions(usingL)
    let resolved = []

    for using in a:usingL
        let matches = []

        if using.text[0] == ':'
            " Using-directive
            let name = using.text[2:]
            let kind = 'n'
        else
            " Using-declaration
            let name = using.text
            " Match any object type
            let kind = ''
        endif

        let prefix = split(name,'::')[:-2]
        let dirs = filter(copy(using.complete),'v:val[0]==":"')

        " Warning: matching against the full name, and not only the
        " last part, requires tags to be generated using '--extra=+q'
        for item in taglist('\V\C'.name.'\$')
            if s:IsVisible(using, item) && (empty(kind) || item.kind == kind)
                " The prefix context that is not included in the
                " using-instruction's text
                let unmatched = split(omnicpp#tag#Context(item),'::')[:-len(prefix)-1]

                " Only preceding using-directives can be combined to
                " form the unmatched prefix
                for dir in dirs
                    if empty(unmatched) | break | endif
                    let subdirs = split(dir,'::')
                    if subdirs == unmatched[:len(subdirs)-1]
                        let unmatched = unmatched[len(subdirs) :]
                    endif
                endfor

                " The full prefix matched, context was resolved
                if empty(unmatched) | call add(matches,item) | endif
            endif
        endfor

        " Ambiguous contexts are not kept
        call s:FilterDuplicates(matches)
        if len(matches) == 1
            call add(resolved, ((matches[0].kind=='n')?'::':'').matches[0].name)
        endif
    endfor

    return resolved
endfunc

" Check if a tag is reachable using a list of included/partial files.
"
" @param using Using-instruction object, see s:FromGraph()
" @param tag Tag object to check
"
" @return 1 if the tag is visible, 0 otherwise
"
func! s:IsVisible(using,tag)
    let path = omnicpp#tag#Path(a:tag)

    if index(a:using.complete, path) >= 0 | return 1 | endif

    for part in a:using.partial
        if path == part.file
            return get(a:tag,'line',0) <= part.line
        endif
    endfor

    return 0
endfunc

" When multiple tags match a using-instruction, remove duplicates due to
" the use of '--extra=+q', keeping only the fully qualified name.
"
" @param matches List of matching tags
" @return None
"
func! s:FilterDuplicates(matches)
    " 2 matches with same context; since we know they end the same, we
    " have duplicates
    if len(a:matches) == 2 &&
                \ omnicpp#tag#using(a:matches[0]) == omnicpp#tag#Context(a:matches[1])

        if match(a:matches[0].name, a:matches[1].name) >= 0
            " First match has a qualified name
            call remove(a:matches, 1)
        else
            call remove(a:matches, 0)
        endif
    endif
endfunc
