" Author: Bassam JABBOUR
" Description: Utility functions for working with tags

" Resolve the filename attribute of a tag by rooting relative paths at
" the current directory; absolute paths are left unchanged.
"
" @param item Tag item, as returned by a taglist() query
" @return absolute path of the file containing the tag
"
func! omnicpp#tag#Path(item)
    return a:item.filename[0] == '/' ? a:item.filename : getcwd().'/'.a:item.filename
endfunc

" Check that the given tag is visible from the current buffer using the
" list of includes given.
"
" @param item see TagPath()
" @param includes List of includes visible from the current buffer
"
" @return 1 if the tag is visible, 0 otherwise
"
func! omnicpp#tag#Visible(item, includes)
    let path = omnicpp#tag#Path(a:item)
    return (path == expand('%:p') && get(a:item,'line',0) <= getpos('.')[1])
                \ || index(a:includes, path) >= 0
endfunc

" Retrieve the context this tag is declared in (the qualified name of
" this tag's parent).
"
" @param see TagVisible()
" @return the parent context, or an empty string if the tag is declared
" in global scope
"
func! omnicpp#tag#Context(item)
    if has_key(a:item, 'namespace')
        return a:item.namespace
    elseif has_key(a:item, 'class')
        return a:item.class
    elseif has_key(a:item, 'struct')
        return a:item.struct
    else
        return ''
    endif
endfunc

" Check if the tag is visible from the current buffer (see
" TagVisible()), and that any context attribute (namespace, class...) is
" actually already included in the item's name (discard names that
" aren't fully qualified).
"
" @param see TagVisible()
" @return 1 if the tag matches, 0 otherwise
"
func! omnicpp#tag#Match(item, includes)
    return omnicpp#tag#Visible(a:item, a:includes)
                \ && match(a:item.name, omnicpp#tag#Context(a:item)) == 0
endfunc

" Check if a tag is accessible through a list of using-declarations.
"
" @param item a tag item, as returned by taglist()
" @param declarations list of using-declarations to search
" @return 1 if the item is accessible through the using-declarations, 0
" otherwise
"
func! omnicpp#tag#Declarations(item, declarations)
    let context = omnicpp#tag#Context(a:item)
    " A tag outside a context cannot match any using-declaration
    if empty(context) | return 0 | endif

    for dec in a:declarations
        let prefix = join(split(dec,'::')[:-2],'::')
        let name = split(dec,'::')[-1]

        if a:item.name == name &&
                    \ context == prefix
            return 1
        endif
    endfor

    return 0
endfunc

func! omnicpp#tag#Cmd(item)
    return substitute(a:item.cmd, '^/\^\|\$/$','','g')
endfunc
