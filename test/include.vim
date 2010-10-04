" Author: Bassam JABBOUR
" Description: Test suite for include.vim

let b:testFile = "include.cpp"

func! g:TestLocalIncludes()
    let includes = omnicpp#include#LocalIncludes()
    call sort(includes)
    call g:Assert(includes == ['"l1.h"', '"l3.h"', '<l2.h>'])
endfunc

func! g:TestGlobalIncludes()
    let includes = omnicpp#include#GlobalIncludes()
    call sort(includes)
    call g:Assert(includes == ['"g1.h"', '<g2.h>'])
endfunc

func! g:TestAllIncludes()
    let includes = omnicpp#include#AllIncludes()
    call sort(includes)

    call g:Assert(includes[0:2] == [expand('%:p:h').'/include.cpp',
                \ expand('%:p:h').'/include.h',
                \ expand('%:p:h').'/include2.h'])
    call g:Assert(index(includes, '/usr/include/string.h') >= 0)
endfunc
