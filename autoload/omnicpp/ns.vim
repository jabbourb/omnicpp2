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

" Parse the given files for using-directives.
func! omnicpp#ns#ParseDirectives(files)
    return s:ParseUsing(a:files, s:reDirective, s:cacheDir)
endfunc

" Parse the given files for using-declarations.
func! omnicpp#ns#ParseDeclarations(files)
    return s:ParseUsing(a:files, s:reDeclaration, s:cacheDec)
endfunc

" Parse the current buffer up to the cursor's position for local/global
" using-directives, as well as any included file, recursively.
func! omnicpp#ns#CurrentDirectives()
    let dirs = omnicpp#scope#MatchLocal(s:reDirective) + omnicpp#scope#MatchGlobal(s:reDirective)
    call map(dirs, 'substitute(v:val,"\\s\\+","","g")')
    let incs = omnicpp#include#CurrentBuffer()
    return dirs + omnicpp#ns#ParseDirectives(incs)
endfunc

" Parse the current buffer up to the cursor's position for local/global
" using-declarations, as well as any included file, recursively.
func! omnicpp#ns#CurrentDeclarations()
    let decs = omnicpp#scope#MatchLocal(s:reDeclaration) + omnicpp#scope#MatchGlobal(s:reDeclaration)
    call map(decs, 'substitute(v:val,"\\s\\+","","g")')
    let incs = omnicpp#include#CurrentBuffer()
    return decs + omnicpp#ns#ParseDeclarations(incs)
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
    " namespaces, 1 otherwise), and using instructions up to the
    " cursor's position.
    let contexts = []

    while searchpair('{','','}','bW','omnicpp#utils#IsCursorInCommentOrString()')
        let instruct = omnicpp#utils#ExtractInstruction()

        " Explicit namespace directive
        let ns = matchstr(instruct, '\v<namespace>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*$')
        if !empty(ns)
            call insert(contexts, {'name' : ns, 'type' : 0})
            continue
        endif

        let dec = map(omnicpp#ns#CurrentDeclarations(), 'split(v:val,"::")[-1]')
        let dir = omnicpp#ns#CurrentDirectives()

        " Class declaration
        let cls = matchstr(instruct, '\v<class>\s+\zs'.g:omnicpp#syntax#reIdSimple.'\ze\s*(:|$)')
        if !empty(cls)
            call insert(contexts, {'name' : cls, 'type' : 1,
                        \ 'dec' : dec, 'dir' : dir})
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
                                \ 'dec' : dec, 'dir' : dir})
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
            call extend(inherit, omnicpp#ns#BaseClasses(context))
        endif

        call insert(nest, len(nest)==1 ? context['name'] : nest[0].'::'.context['name'])
    endfor

    return extend(nest,inherit,-1)
endfunc

" Given a class/struct, look up its declaration, then extract inherited
" classes recursively. Inherited classes are resolved by searching
" nesting blocks around the declaration, as well as using-directives and
" using-declarations visible at that point.
"
" @param class a dictionary representing the class to lookup:
"   - name: the class' name (unqualified)
"   - nest: nesting around the class declaration; see s:GetNest()
"   - dir:  using-directives visible from the class' declaration
"   - dec:  using-declarations visible from the class' declaration
"
" @return a list of inherited contexts, qualified
"
func! omnicpp#ns#BaseClasses(class)

    " Unresolved class names
    let inherits = [a:class]
    " Qualified class names
    let qualified = []

    while !empty(inherits)
        let inherit = remove(inherits,-1)

        for item in taglist('\V\C\^'.inherit['name'].'\$')
            let path = omnicpp#tag#Path(item)
            let includes = omnicpp#include#ParseRecursive(path)

            if omnicpp#tag#Visible(item, includes)
                let context = omnicpp#tag#Context(item)

                if index(inherit.nest + inherit.dir, context) >= 0
                            \ || index(inherit.dec, inherit.name) >=0
                    call add(qualified, empty(context) ? item['name'] : context.'::'.item['name'])

                    let nest = s:GetNest(context)
                    let dir = omnicpp#ns#ParseDirectives([path]+includes)
                    let dec = omnicpp#ns#ParseDeclarations([path]+includes)
                    call map(dec, 'split(v:val,"::")[-1]')

                    for name in split(get(item,'inherits',''),',')
                        call add(inherits, {'name' : name, 'nest' : nest,
                                    \ 'dir' : dir, 'dec' : dec})
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


" === Auxiliary ========================================================

" Parse a list of files for a given expression, using/updating the
" cache. Spaces and duplicates are then removed.
"
" @param entries List of files to parse, usually obtained through
" includes analysis
" @param regexp Regexp to look for
" @param cache Cache object to use (for up-to-date entries) or update
" (for outdated/new entries)
"
" @return List of matches
"
func! s:ParseUsing(entries, regexp, cache)
    let matches = []

    for entry in a:entries
        if !a:cache.has(entry)
            call a:cache.put(entry, omnicpp#utils#VGrep(entry, a:regexp))
        endif
        call extend(matches, a:cache.get(entry))
    endfor

    call map(matches, 'substitute(v:val,"\\s\\+","","g")')
    call filter(matches, 'count(matches,v:val)==1')

    return matches
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
