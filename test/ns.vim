" Author: Bassam JABBOUR
" Description: Unit tests for ns.vim

let b:testFile = "ns.cpp"

func! g:TestLocalUsing()
    let declarations = omnicpp#ns#LocalUsingDeclarations()
    call g:Assert(declarations==['n1::n2::cls1', 'n1::cls1'])

    let directives = omnicpp#ns#LocalUsingDirectives()
    call g:Assert(directives==['n1::n2', 'n2', 'n1'])
endfunc

func! g:TestGlobalUsing()
    let declarations = omnicpp#ns#GlobalUsingDeclarations()
    call g:Assert(declarations==['g1::g2::c2', 'g1::c1'])

    let directives = omnicpp#ns#GlobalUsingDirectives()
    call g:Assert(directives==['g1::g2', 'g1'])
endfunc
