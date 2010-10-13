" Author: Bassam JABBOUR
" Description: Test suite for cache.vim

func! g:TestCache()
    let cache = omnicpp#cache#Create()
    call g:Assert(!cache.has('any'))

    let curBuf = expand('%:p')
    call cache.put(curBuf, [0])
    call g:Assert(cache.has(curBuf))
    call g:Assert(cache.get(curBuf) == [0])

    write
    call g:Assert(!cache.has(curBuf))
endfunc
