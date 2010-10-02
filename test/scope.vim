" Author: Bassam JABBOUR
" Description: Test suite for omnicpp#scope

let b:testFile = "scope.cpp"

func! g:TestLocal()
    call g:Assert(len(omnicpp#scope#MatchLocal('var1')) == 1)
    call g:Assert(len(omnicpp#scope#MatchLocal('var2')) == 0)
endfunc

func! g:TestGlobal()
    call g:Assert(len(omnicpp#scope#MatchGlobal('var1')) == 2)
    call g:Assert(len(omnicpp#scope#MatchGlobal('var2')) == 1)
    call g:Assert(len(omnicpp#scope#MatchGlobal('var3')) == 1)
    call g:Assert(len(omnicpp#scope#MatchGlobal('var4')) == 0)
endfunc
