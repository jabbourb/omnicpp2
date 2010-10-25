" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace and context
" resolution.

" === Data =============================================================

" The following regexes extract namespaces as XX::YY
" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives; keep leading 'namespace'
" keyword distinguish those from declarations when grepping
let s:reDirective = '\C\v<using>\s+\zs<namespace>\s+\w+(\s*::\s*\w+)*\ze\s*;'

let g:omnicpp#context#reUsing = '^\s*'.s:reDeclaration.'|^\s*'.s:reDirective

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
func! omnicpp#context#FileRecursive(filename,...)
    let graph = omnicpp#graph#Graph(a:filename)
    call graph.root.addChildren(omnicpp#parse#File(graph.root.text, get(a:000,0,0)))
    return s:ResolveUsing(s:UsingFromGraph(graph))
endfunc

" When inside a context definition/declaration, or when implementing a
" method using its qualified name, list all contexts visible at the
" cursor's position (namespaces, classes...)
"
" @return List of namespaces
"
func! omnicpp#context#Current()
    let origPos = getpos('.')
    " For every context found, store its name, a binary type (0 for
    " namespaces, 1 otherwise), and using instructions up to the
    " cursor's position.
    let contexts = []

    let globalInc = omnicpp#include#FileRecursive(omnicpp#include#Global())
    let globalUsing = s:GlobalUsing() + omnicpp#context#FileRecursive(globalInc)

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*$')
        if !empty(ns)
            call insert(contexts, {'name' : ns, 'type' : 0})
            continue
        endif

        let localInc = omnicpp#include#FileRecursive (omnicpp#include#Local())

        let using = s:LocalUsing +
                    \ omnicpp#context#FileRecursive (localInc) +
                    \ globalUsing
        let inc = localInc + globalInc
        call filter(using, 'count(using, v:val) == 1')

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*(:|$)')
        if !empty(cls)
            call insert(contexts, {'name' : cls, 'type' : 1,
                        \ 'using' : using, 'inc' : inc})
            continue
        endif

        " Scope in function definition
        if match(instruct, ')\s*$')
            let instruct = substitute (instruct, ')\s*$', '', '')
            let endPos = omnicpp#utils#SearchPairBack (instruct, '(', ')') - 1
            if endPos >= 0
                " We only check for compound names (:: separated) and
                " skip plain ones (and keywords btw)
                for simpleContext in reverse(split(substitute(matchstr(
                            \ instruct[:endPos],'\('.g:omnicpp#syntax#reIdSimple.'\s*::\s*)+\ze'.g:omnicpp#syntax#reIdSimple.'\s*$'),
                            \ '\s\+', '', 'g'), '::'))
                    call insert(contexts, {'name' : simpleContext, 'type' : 1,
                                \ 'using' : using, 'inc' : inc})
                endfor
            endif
        endif
    endwhile

    call setpos('.', origPos)

    " List of contexts made available by nesting blocks, by order of
    " precedence. We start with the global (empty) context.
    let nest = ['']

    for context in contexts
        let last = nest[0]
        if context.type
            let context.nest = nest
            call extend(nest, omnicpp#context#BaseClasses(context), 0)
        endif

        call insert(nest, empty(last) ? context['name'] : last.'::'.context['name'])
    endfor

    return nest
endfunc

" Given a class/struct, look up its declaration, then extract inherited
" classes recursively. Inherited classes are resolved by searching
" nesting blocks around the declaration, as well as using-directives and
" using-declarations visible at that point.
"
" @param class a dictionary representing the class to lookup:
"   - name: the class' name (unqualified)
"   - inc:  includes visible at the declaration's position
"   - nest: nesting around the class declaration; see s:GetNest()
"   - dir:  using-directives visible from the class' declaration
"   - dec:  using-declarations visible from the class' declaration
"
" @return a list of inherited contexts, qualified
"
func! omnicpp#context#BaseClasses(class)
    " Unresolved class names
    let inherits = [a:class]
    " Qualified class names
    let qualified = []

    while !empty(inherits)
        let inherit = remove(inherits,-1)

        for item in taglist('\V\C\^'.inherit['name'].'\$')
            if omnicpp#tag#Visible(item, inherit.inc)
                let context = omnicpp#tag#Context(item)

                " TODO Matching against inherit.dec can be refactored
                if index(inherit.nest + inherit.dir, context) >= 0
                            \ || index(inherit.dec, inherit.name) >=0
                    call add(qualified, empty(context) ? item['name'] : context.'::'.item['name'])

                    let path = omnicpp#tag#Path(item)

                    let nest = s:GetNest(context)
                    let inc = omnicpp#include#ParseRecursive(path, get(item,'line',0))
                    let dir = omnicpp#context#ParseDirectives(path, get(item,'line',0))
                                \ + omnicpp#context#ParseDirectives(inc)
                    let dec = omnicpp#context#ParseDeclarations(path, get(item,'line',0))
                                \ + omnicpp#context#ParseDeclarations(inc)
                    call map(dec, 'split(v:val,"::")[-1]')

                    for name in split(get(item,'inherits',''),',')
                        call add(inherits, {'name' : name, 'nest' : nest,
                                    \ 'dir' : dir, 'dec' : dec, 'inc' : inc})
                    endfor
                    break
                endif
            endif
        endfor
    endwhile

    " Remove the base class
    if !empty(qualified) | call remove(qualified,0) | endif
    return qualified
endfunc

" Sanitize an extracted using-instruction. Spaces are removed, and
" leading 'namespace' keyword in directives is replaced by '::'.
"
" @param context Instruction to sanitize
" @return List of sanitized instructions (using-declarations as XX::YY,
" and using-directives as ::XX::YY)
"
func! omnicpp#context#Sanitize(context)
    return substitute(substitute(a:context, '^namespace\>', '::', ''), '\s\+', '', 'g')
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
func! s:UsingFromGraph(graph)
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

" Resolve using instructions using the context and visibility
" information provided.
"
" @param usingL List of using-objects, as returned by s:UsingFromGraph()
" @return List of tag items, each representing a resolved, unambiguous
" using-instruction
"
func!  s:ResolveUsing(usingL)
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
            if s:UsingVisible(using, item) && (empty(kind) || item.kind == kind)
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
        call s:ResolveDuplicates(matches)
        if len(matches) == 1
            call add(resolved, matches[0])
        endif
    endfor

    return resolved
endfunc

" Check if a tag is reachable using a list of included/partial files.
"
" @param using Using-instruction object, see s:UsingFromGraph()
" @param tag Tag object to check
"
" @return 1 if the tag is visible, 0 otherwise
"
func! s:UsingVisible(using,tag)
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
func! s:ResolveDuplicates(matches)
    " 2 matches with same context; since we know they end the same, we
    " have duplicates
    if len(a:matches) == 2 &&
                \ omnicpp#tag#Context(a:matches[0]) == omnicpp#tag#Context(a:matches[1])

        if match(a:matches[0].name, a:matches[1].name) >= 0
            " First match has a qualified name
            call remove(a:matches, 1)
        else
            call remove(a:matches, 0)
        endif
    endif
endfunc

" Given a context string (xx::yy::zz), return all visible sub-contexts
" (in this case, [xx::yy::zz::, xx::yy::, xx::, ''])
func! s:GetNest(context)
    let nests = []
    let elems = split(a:context, '::')
    for elem in elems
        call insert(nests, empty(nests) ? elem : nests[0].'::'.elem)
    endfor
    call add(nests, '')
    return nests
endfunc
