" Author: Bassam JABBOUR
" Description: Test suite for utils.vim

func! g:TestTagMatch()
    let tag1 = {'name' : 'tag1', 'filename' : expand('%:p')}
    let tag2 = {'name' : 'tag2', 'filename' : 'someFile.h'}
    let tag3 = {'name' : 'tag3', 'filename' : expand('%:p'), 'namespace' : 'n1'}
    let tag4 = {'name' : 'c1::tag4', 'filename' : expand('%:p'), 'class' : 'c1'}
    call g:Assert (omnicpp#utils#TagMatch(tag1, []))
    call g:Assert (!omnicpp#utils#TagMatch(tag2, []))
    call g:Assert (omnicpp#utils#TagMatch(tag2, [expand('%:p:h').'/'.'someFile.h']))
    call g:Assert (!omnicpp#utils#TagMatch(tag3, []))
    call g:Assert (omnicpp#utils#TagMatch(tag4, []))
endfunc
