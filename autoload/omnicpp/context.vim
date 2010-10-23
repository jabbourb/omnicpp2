" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace and context
" resolution.

" === Data =============================================================

" The following regexes extract namespaces as XX::YY
" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives; keep trailing ';' to
" distinguish it from declarations when grepping
let s:reDirective = '\C\v<using>\s+<namespace>\s+\zs\w+(\s*::\s*\w+)*\s*;'

let g:omnicpp#context#reUsing = s:reDirective.'|'.s:reDeclaration

" Cache the list of using directives/declarations
let s:cache = omnicpp#cache#Create()

let s:cacheDir = omnicpp#cache#Create()
let s:cacheDec = omnicpp#cache#Create()

" === Functions ========================================================

" Parse the given file for using-instructions. If a line is specified,
" perform a partial parse up to that position without updating the
" cache.
"
" @param file File to parse
" @param ... A non-zero numeric argument will stop parsing at
" that line number
" @return List of using-instructions, sanitized. Using-declarations are
" extracted as XX::YY, and using-directives as XX::YY::
"
func! omnicpp#context#File(file, ...)
    if s:cache.has(a:file) && !a:0
        return s:cache.get(a:file)
    endif

    let reUsing = '^\s*'.s:reDeclaration.'|^\s*'.s:reDirective
    let using = omnicpp#parse#Grep(a:file, reUsing, get(a:000,0,0))
    call s:ParsePost(using)

    if !a:0 | call s:cache.put(a:file, using) | endif
    return using
endfunc

" Parse the given file(s) recursively. If a single file is given, parse
" that file for using-instructions and includes up to a given line, if
" specified, then recursively parse those includes for contexts. If a
" list of files is specified, simply parse those, ignoring any optional
" argument.
"
" @param entry File or list of files to parse
" @param ... In the case of a single file, a non-zero argument will stop
" parsing that file on the specified line
" @return List of using-instructions (see Parse())
"
func! omnicpp#context#FileRecursive(entry, ...)
    if type(a:entry) == type('')
        let matches = omnicpp#context#File(a:entry, get(a:000,0,0))
        let files = omnicpp#include#ParseRecursive(a:entry, get(a:000,0,0))
    else
        let matches = []
        let files = copy(a:entry)
    endif

    for file in reverse(files)
        call extend(matches, omnicpp#context#File(file), 0)
    endfor

    return matches
endfunc

func! omnicpp#context#Buffer()
    return s:LocalUsing() + s:GlobalUsing()
endfunc

func! omnicpp#context#BufferRecursive()
    let using = omnicpp#context#Buffer()
    let incs = omnicpp#include#CurrentBuffer()
    return using + omnicpp#context#ParseRecursive(incs)
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

func! omnicpp#context#Sanitize(context)
    return substitute(substitute(a:context, '\s*;$', '::', ''), '\s\+', '', 'g')
endfunc

" === Auxiliary ========================================================

" Clean up the using-instructions by appending '::' to directives and
" removing spaces.
func! s:ParsePost(matches)
    " Add '::' to using-directives
    call map(a:matches, 'substitute(v:val, "\\s*;$", "::", "")')
    " Remove spaces
    return map(a:matches, 'substitute(v:val,"\\s\\+","","g")')
endfunc

func! s:LocalUsing()
    return s:ParsePost(omnicpp#scope#MatchLocal(s:reUsing))
endfunc

func! s:GlobalUsing()
    return s:ParsePost(omnicpp#scope#MatchGlobal(s:reUsing))
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
