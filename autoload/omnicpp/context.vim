" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace and context
" resolution.

" When inside a context definition/declaration, or when implementing a
" method using its qualified name, list all contexts visible at the
" cursor's position (namespaces, classes...)
"
" @return List of contexts, in order of precedence, with a leading '::'
"
func! omnicpp#context#Current()
    let origPos = getpos('.')
    " For every context found, store its name, a binary flag indicating
    " if this context is to be looked up as a potential class, and using
    " instructions up to the cursor's position.
    let contexts = []

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*$')
        if !empty(ns)
            call insert(contexts, {'name' : ns, 'lookup' : 0})
            continue
        endif

        " TODO write a using#BufferRecursive() function
        let using = omnicpp#using#FileRecursive(expand('%:p'),getpos('.')[1])
        let inc = omnicpp#include#BufferRecursive()

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*(:|$)')
        if !empty(cls)
            call insert(contexts, {'name' : cls, 'lookup' : 1,
                        \ 'using' : using, 'inc' : inc})
            continue
        endif

        " Scope in function definition
        if match(instruct, ')\s*$')
            let instruct = substitute (instruct, ')\s*$', '', '')
            let endPos = omnicpp#utils#SearchPairBack (instruct, '(', ')') - 1
            if endPos >= 0
                " We only check for compound names (:: separated) and
                " skip plain ones (and keywords)
                for simpleContext in reverse(split(substitute(matchstr(
                            \ instruct[:endPos],'\('.g:omnicpp#syntax#reIdSimple.'\s*::\s*)+\ze'.g:omnicpp#syntax#reIdSimple.'\s*$'),
                            \ '\s\+', '', 'g'), '::'))
                    call insert(contexts, {'name' : simpleContext, 'lookup' : 1,
                                \ 'using' : using, 'inc' : inc})
                endfor
            endif
        endif
    endwhile

    call setpos('.', origPos)

    " List of contexts made available by nesting blocks, by order of
    " precedence. We start with the global (empty) context.
    let nest = []

    for context in contexts
        let last = get(nest,0,'')
        if context.lookup
            call extend(nest, s:BaseClasses(context,last), 0)
        endif

        call insert(nest, last.'::'.context.name)
    endfor

    return nest
endfunc

" Given a class/struct, look up its declaration, then extract inherited
" classes recursively. Inherited classes are resolved by searching
" nesting blocks around the declaration, as well as using-directives and
" using-declarations visible at that point.
"
" TODO precedence rules for tag matches (for the current buffer, since
" there is no local/global distinction in other files)
"
" @param class a dictionary representing the class to lookup:
"   - name:  the class' name (unqualified)
"   - inc:   includes visible at the declaration's position
"   - using: using-instructions visible from the class' declaration
" @param nest path to the class' declaration in a single string
" 'XX::YY::...'
"
" @return a list of inherited contexts, qualified
"
func! s:BaseClasses(class,nest)
    " The starting class is to be looked up only with that exact path,
    " while base classes will be looked up along all the components of
    " that path, obtained through GetNest(); hence the 'list' format.
    let a:class.nest = empty(a:nest) ? [] : [a:nest]

    " Unresolved class names
    let inherits = [a:class]
    " Qualified class names
    let qualified = []

    while !empty(inherits)
        let inherit = remove(inherits,-1)

        " The exact tag name to lookup, including any context.
        let tagQuery = '\V\C\^\('.inherit.name
        for context in inherit.nest+inherit.using
            if context[0] == ':'
                " Namespaces
                let tagQuery .= '\|'.context[2:].'::'.inherit.name
            elseif split(context,'::')[-1] == inherit.name
                " Using-declarations
                let tagQuery .= '\|'.context
            endif
        endfor
        let tagQuery .= '\)\$'

        for item in taglist(tagQuery)
            if omnicpp#tag#Match(item, inherit.inc)
                call add(qualified, '::'.item.name)

                let path = omnicpp#tag#Path(item)
                let nest = s:GetNest(omnicpp#tag#Context(item))
                let inc = omnicpp#include#FileRecursive(path, get(item,'line',0))
                let using = omnicpp#using#FileRecursive(path, get(item,'line',0))
                for name in split(get(item,'inherits',''),',')
                    call add(inherits, {'name' : name, 'nest' : nest,
                                \ 'using' : using, 'inc' : inc})
                endfor
                break
            endif
        endfor
    endwhile

    " Remove the base class
    if !empty(qualified) | call remove(qualified,0) | endif
    return qualified
endfunc

" Given a context string (xx::yy::zz), return all visible sub-contexts
" (in this case, [xx::yy::zz::, xx::yy::, xx::, ''])
func! s:GetNest(context)
    let nests = []
    let elems = split(a:context, '::')
    for elem in elems
        call insert(nests, get(nests,0,'').'::'.elem)
    endfor
    return nests
endfunc
