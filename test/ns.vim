" Author: Bassam JABBOUR
" Description: Unit tests for ns.vim

let b:testFile = "ns.cpp"

func! g:TestLocalUsing()
    let declarations = omnicpp#ns#LocalUsingDeclarations()
    call g:Assert(declarations==['n1::cls1', 'n1::n2::cls1'])

    let directives = omnicpp#ns#LocalUsingDirectives()
    call g:Assert(directives==['n1', 'n2', 'n1::n2'])
endfunc

func! g:TestGlobalUsing()
    let declarations = omnicpp#ns#GlobalUsingDeclarations()
    call g:Assert(declarations==['g1::c1', 'g1::g2::c2', 'std::vector'])

    let directives = omnicpp#ns#GlobalUsingDirectives()
    call g:Assert(directives==['g1', 'g1::g2', 'std'])
endfunc

func! g:TestCurrentNS1()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1', 'n1::n2', 'n1::n2::A'])
endfunc

func! g:TestCurrentNS2()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1', 'n1::n2', 'n1::n2::A'])
endfunc

func! g:TestCurrentNS3()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1', 'n1::n2'])
endfunc

func! g:TestCurrentNS4()
    call g:Assert (omnicpp#ns#CurrentContexts() == ['n1', 'n1::n2', 'n1::n2::A'])
endfunc

func! g:TestCurrentNS5()
    call g:Assert (empty(omnicpp#ns#CurrentContexts()))
endfunc
