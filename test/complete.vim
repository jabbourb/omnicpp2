" Author: Bassam JABBOUR
" Description: Test suite for complete.vim

let b:testFile="complete.cpp"

func! g:TestAny()
    call omnicpp#complete#Main(0,0)
    call g:Assert (sort(omnicpp#complete#Any('c')) == ['c2', 'c4', 'c5', 'c7'])
    call g:Assert (empty(omnicpp#complete#Any('veryUnlikelyName')))
endfunc

func! g:TestQualified()
    call omnicpp#complete#Main(0,0)
    call g:Assert (omnicpp#complete#Qualified('n1::c') == ['c5'])
    call g:Assert (empty(omnicpp#complete#Qualified('n3::c')))
endfunc
