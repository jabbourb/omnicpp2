" Author: Bassam JABBOUR
" Description: Test suite for type.vim

let b:testFile="declare.cpp"

func! s:CreateType(base, pointer, array)
    return {'base': a:base, 'pointer': a:pointer, 'array': a:array}
endfunc

func! g:TestLocalType()
    call g:Assert (omnicpp#declare#LocalType('rootPoint') == s:CreateType('Ogre::Root', 1, 0))
    call g:Assert (omnicpp#declare#LocalType('vecArr') == s:CreateType('std::vector', 0, 1))
    call g:Assert (omnicpp#declare#LocalType('intPointArr') == s:CreateType('int', 1, 1))
    call g:Assert (omnicpp#declare#LocalType('a') == s:CreateType('int', 0, 0))
    call g:Assert (omnicpp#declare#LocalType('b') == s:CreateType('int', 0, 0))
    call g:Assert (omnicpp#declare#LocalType('c') == s:CreateType('int', 1, 1))
    call g:Assert (omnicpp#declare#LocalType('i1') == s:CreateType('int', 0, 0))
endfunc

func! g:TestLocalVars()
    call g:Assert (omnicpp#declare#LocalVars('root') == ['rootPoint'])
    call g:Assert (omnicpp#declare#LocalVars('i') == ['intPointArr', 'i1'])
    call g:Assert (empty(omnicpp#declare#LocalVars('anUnlikelyBase')))
endfunc
