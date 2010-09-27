" Author: Bassam JABBOUR
" Description: Minimalist test framework

let s:reTest = '^\s*fu\%[nction]!\=\s\+\zsb:Test.\{-}\ze[ (]'

func! b:Assert (expr)
    if empty(a:expr) | throw "Assert" | endif
endfunc

func! s:RunTests()
    let origPos = getpos('.')
    so %
    norm gg

    let numTests = 0
    let success = 0
    let fail = 0

    while search(s:reTest, 'W')
        if index(['vimComment', 'vimString'], synIDattr(synID(line('.'), col('.'), 0), 'name')) >= 0 | continue | endif

        let start = getpos('.')[2]
        let end = searchpos(s:reTest, 'We')[1]
        let Test = function(getline('.')[start-1 : end-1])

        let numTests += 1
        echo Test
        try
            call Test()
            echo "\tSuccess"
            let success += 1
        catch /Assert/
            echo "\tFailure"
            let fail += 1
        endtry
    endwhile

    echo numTests  "tests,"  success "ok,"  fail  "failed"
    call setpos('.', origPos)
endfunc

command! RunTests call <SID>RunTests()
