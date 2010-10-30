" Author: Bassam JABBOUR
" Description: Functions for looking up and resolving using-instructions

" === Data =============================================================

" The following regexes extract namespaces as XX::YY
" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives; keep leading 'namespace'
" keyword distinguish those from declarations when grepping
let s:reDirective = '\C\v<using>\s+\zs<namespace>\s+\w+(\s*::\s*\w+)*\ze\s*;'

let g:omnicpp#using#reUsing = s:reDeclaration.'|'.s:reDirective

" === Functions ========================================================

" Recursively parse a file for using-instructions, and resolve them.
" Internally, we build a graph around file dependencies, then extract
" the data by walking through that graph based on the order the
" instructions appear in; includes are visited only once to avoid
" circular dependencies, while using-instructions are not filtered.
"
" @param filename File to parse
" @param ... a non-zero numeric argument stops parsing the main file at
" the specified line
"
" @return List of valid using-instructions; using-directives have a '::'
" prepended
"
func! omnicpp#using#FileRecursive(filename,...)
    let graph = omnicpp#graph#Graph(a:filename)
    call graph.root.addChildren(omnicpp#parse#File(graph.root.text, get(a:000,0,0)))
    return s:FromGraph(graph)
endfunc

" Recursively parse the current buffer up to the cursor's position for
" using-instructions, and resolve them.
" (see using#FileRecursive() for details)
"
" TODO when resolving using-instructions, local instructions should take
" precedence over global ones
"
" @return see using#FileRecursive()
"
func! omnicpp#using#BufferRecursive()
   let graph = omnicpp#graph#Graph(expand('%:p'))
   let global = omnicpp#parse#Global()
   let local = omnicpp#parse#Local()
   call graph.root.addChildren(global+local)
   return s:FromGraph(graph)
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

            let resolved = s:ResolveInstruction(using)
            " Update the graph so that subsequent nodes see the resolved
            " instruction
            let a:graph.current.text = resolved
            if !empty(resolved) | call add(usingL, resolved) | endif
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
func!  s:ResolveInstruction(using)
    let matches = []

    if a:using.text[0] == ':'
        " using-directive
        let text = a:using.text[2:]
        let kind = 'n'
    else
        " using-declaration
        let text = a:using.text
        " Match any object type
        let kind = ''
    endif

    " Last part of the using-instruction's text
    let name = split(text,'::')[-1]
    " Prefix context appearing in the using-instruction's text
    let context = join(split(text,'::')[:-2],'::')

    " List of includes
    let incs = filter(copy(a:using.complete), 'v:val[0]=="/"')
    " Append the prefix context to the list of using-directives
    let dirs = map(filter(copy(a:using.complete), 'v:val[0]==":"'),'v:val[2:]."::".context')

    for item in taglist('\V\C\^'.name.'\$')
        if s:TagVisible(item, incs, a:using.partial, context, dirs) &&
                    \ (empty(kind) || item.kind == kind)
            call add(matches, item)
        endif
    endfor

    " Ambiguous contexts are not kept
    if len(matches) == 1
        let context = omnicpp#tag#Context(matches[0])
        if !empty(context) | let context .= '::' | endif

        return ((matches[0].kind=='n')?'::':'')
                    \ .context
                    \ .matches[0].name
    endif

    return ''
endfunc

" Check that a tag is reachable based on a list of visible files and
" imported contexts.
"
" @param tag Tag object to verify
" @param incs List of visible includes
" @param partial List of partially visible files. Each object has 'file'
" and 'line' entries, the file being visible up to the specified line
" @param context the prefix context appearing in the using-instruction's
" text
" @param dirs  using-directives preceding the instruction being looked
" up, with the prefix context appended to each entry
"
" @return 1 if the tag is visible, 0 otherwise
"
func! s:TagVisible(tag, incs, partial, context, dirs)
    let path = omnicpp#tag#Path(a:tag)

    let valid = (index(a:incs, path) >= 0)

    if !valid
        for part in a:partial
            if path == part.file
                let valid = (get(a:tag,'line',0) <= part.line)
                break
            endif
        endfor
    endif

    if valid
        let context = omnicpp#tag#Context(a:tag)
        let valid = (context == a:context || index(a:dirs, context) >= 0)
    endif

    return valid
endfunc
