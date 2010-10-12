" Author: Bassam JABBOUR
" Description: Test suite for complete.vim

let b:testFile="complete.cpp"

func! g:TestVars()
    call g:Assert (sort(omnicpp#complete#Vars('c')) == ['c1', 'c2', 'c3', 'c4', 'c5', 'c7'])
endfunc
