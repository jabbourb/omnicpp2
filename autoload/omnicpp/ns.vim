" Author: Bassam JABBOUR
" Description: Functions for dealing with namespace and context
" resolution.

" === Data =============================================================

" The following regexes extract namespaces as XX::YY
" Regex used for matching using-declarations
let s:reDeclaration = '\C\v<using>\s+\zs\w+(\s*::\s*\w+)+\ze\s*;'
" Regex used for matching using-directives
let s:reDirective = '\C\v<using>\s+<namespace>\s+\zs\w+(\s*::\s*\w+)*\ze\s*;'

" Cache the list of using directives/declarations
let s:cacheDir = omnicpp#cache#Create()
let s:cacheDec = omnicpp#cache#Create()

" === Functions ========================================================

function! omnicpp#ns#LocalUsingDeclarations()
    return map(omnicpp#scope#MatchLocal(s:reDeclaration), 'substitute(v:val,"\\s\\+","","g")')
endfunc

function! omnicpp#ns#LocalUsingDirectives()
    return map(omnicpp#scope#MatchLocal(s:reDirective), 'substitute(v:val,"\\s\\+","","g")')
endfunc

function! omnicpp#ns#GlobalUsingDeclarations()
    return s:GlobalUsing(s:reDeclaration, s:cacheDec)
endfunc

function! omnicpp#ns#GlobalUsingDirectives()
    return s:GlobalUsing(s:reDirective, s:cacheDir)
endfunc


" When inside a context definition/declaration, or when implementing a
" method using its qualified name, list all contexts visible at the
" cursor's position (namespaces, classes...)
"
" @return List of namespaces
"
func! omnicpp#ns#CurrentContexts()
    let origPos = getpos('.')
    " For every context found, store its name, a binary type (0 for
    " namespaces, 1 otherwise), and local using instructions up to the
    " cursor's position.
    let contexts = []

    let gdec = omnicpp#ns#GlobalUsingDeclarations()
    let gdir = omnicpp#ns#GlobalUsingDirectives()

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        let ldec = omnicpp#ns#LocalUsingDeclarations()
        let ldir = omnicpp#ns#LocalUsingDirectives()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*$')
        if !empty(ns)
            call insert(contexts, {'name' : ns, 'type' : 0})
            continue
        endif

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*(:|$)')
        if !empty(cls)
            call insert(contexts, {'name' : cls, 'type' : 1,
                        \ 'ldec' : ldec, 'ldir' : ldir})
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
                                \ 'ldec' : ldec, 'ldir' : ldir})
                endfor
            endif
        endif
    endwhile

    call setpos('.', origPos)

    " List of contexts made available by nesting blocks, longest first.
    " We start with the global (empty) context.
    let nest = ['']
    " List of contexts made available through inheritance at some level.
    let inherit = []

    for context in contexts
        if context.type
            let context.nest = nest
            call extend(inherit, omnicpp#ns#BaseClasses(context, gdir, gdec))
        endif

        call insert(nest, nest[0].context['name'].'::')
    endfor

    return extend(nest,inherit,-1)
endfunc

" Look up the inherited contexts for classes/structs recursively. The
" inheritance is resolved by searching the nested context containing the
" declaration, local using directives and declarations (for the base
" class only), and global using directives and declarations (no
" visibility checks; we use the same list for all lookups).
"
" @param class a dictionary representing the class to lookup:
"   - name : the class' name, unqualified
"   - nest : all contexts made visible by imbricating blocks
"   - ldir : local using directives
"   - ldec : local using declarations
" @param gdir global using directives
" @param gdec global using declarations
"
" @return a list of inherited contexts, qualified
"
func! omnicpp#ns#BaseClasses(class, gdir, gdec)

    " Unresolved class names
    let inherits = [a:class]
    " Qualified class names
    let qualified = []

    while !empty(inherits)
        let inherit = remove(inherits,-1)

        let found = 0
        " Visible contexts
        for ns in inherit.nest + get(inherit,'ldir',[]) + a:gdir
            if found | break | endif

            for item in taglist('\V\C\^'.ns.inherit['name'].'\$')
                let includes = omnicpp#include#ParseRecursive(omnicpp#tag#Path(item))
                if omnicpp#tag#Match(item, includes)
                    call add(qualified, item['name'].'::')
                    let nest = s:GetNest(omnicpp#tag#Context(item))
                    for name in split(get(item,'inherits',''),',')
                        call add(inherits, {'name' : name, 'nest' : nest})
                    endfor
                    let found = 1
                    break
                endif
            endfor
        endfor

        if found | continue | endif

        let found = 0
        " Using declarations with matching name
        for dec in get(inherit,'ldec',[]) + a:gdec
            if found | break | endif
            if split(dec,'::')[-1] != inherit['name'] | continue | endif

            for item in taglist('\V\C\^'.dec.'\$')
                let includes = omnicpp#include#ParseRecursive(omnicpp#tag#Path(item))
                if omnicpp#tag#Match(item, includes)
                    call add(qualified, item['name'].'::')
                    let nest = s:GetNest(omnicpp#tag#Context(item))
                    for name in split(get(item,'inherits',''),',')
                        call add(inherits, {'name' : name, 'nest' : nest})
                    endfor
                    let found = 1
                    break
                endif
            endfor
        endfor
    endwhile

    " Remove the base class
    if !empty(qualified) | call remove(qualified,0) | endif
    return qualified
endfunc


" === Auxiliary ========================================================

func! s:GlobalUsing(regex, cache)
    let using = omnicpp#scope#MatchGlobal(a:regex)
    for inc in omnicpp#include#CurrentBuffer()
        if !a:cache.has(inc)
            let parse = omnicpp#utils#VGrep(inc, a:regex)
            let using += parse
            call a:cache.put(inc, parse)
        else
            let using += a:cache.get(inc)
        endif
    endfor
    call map(using, 'substitute(v:val,"\\s\\+","","g")')
    return filter(using, 'count(using,v:val)==1')
endfunc

" Given a context string (xx::yy::zz), return all visible sub-contexts
" (in this case, [xx::yy::zz::, xx::yy::, xx::, ''])
func! s:GetNest(context)
    let nests = ['']
    let elems = split(a:context, '::')
    for elem in elems
        call insert(nests, nests[0].elem.'::')
    endfor
    return nests
endfunc
