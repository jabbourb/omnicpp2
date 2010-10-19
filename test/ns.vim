" Author: Bassam JABBOUR
" Description: Unit tests for ns.vim

let b:testFile = "ns.cpp"

func! g:TestCurrentNS1()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1::n2::A', 'n1::n2', 'n1', ''])
endfunc

func! g:TestCurrentNS2()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1::n2::A', 'n1::n2', 'n1', ''])
endfunc

func! g:TestCurrentNS3()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1::n2', 'n1', ''])
endfunc

func! g:TestCurrentNS4()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1::n2::A', 'n1::n2', 'n1', ''])
endfunc

func! g:TestCurrentNS5()
    call g:Assert (omnicpp#ns#CurrentContexts() == [''])
endfunc

func! g:TestParseDirectives()
    call g:Assert (omnicpp#ns#ParseDirectives(expand('%:p'), getpos('.')[1]) == ['g1'])
    call g:Assert (omnicpp#ns#ParseDirectives([expand('%:p'), expand('%:p:h').'/ns.h']) == ['g1','n1','std'])
endfunc

func! g:TestParseDeclarations()
    call g:Assert (omnicpp#ns#ParseDeclarations(expand('%:p'), getpos('.')[1]) == ['n1::cls1'])
    call g:Assert (omnicpp#ns#ParseDeclarations([expand('%:p'), expand('%:p:h').'/ns.h']) == ['n1::cls1', 'std::vector'])
endfunc

func! g:TestCurrentBuffer()
    call g:Assert (omnicpp#ns#CurrentDirectives() == ['n1', 'n2', 'n1::n2', 'g1', 'g1::g2', 'std'])
    call g:Assert (omnicpp#ns#CurrentDeclarations() == ['n1::cls1', 'n1::n2::cls1', 'g1::c1', 'std::vector'])
endfunc
