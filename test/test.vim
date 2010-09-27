" Author: Bassam JABBOUR
" Description: Minimalist test framework

if exists('g:TestLoaded')
    finish
else
    let g:TestLoaded = 1
endif

let s:reTest = '^\s*fu\%[nction]!\=\s\+\zsg:Test.\{-}\ze[ (]'

func! g:Assert (expr)
    if empty(a:expr) | throw "Assert" | endif
endfunc

func! s:RunTests()
    let origPos = getpos('.')
    so %
    norm gg

    " List of tests
    let tests = {}
    while search(s:reTest, 'W')
        if index(['vimComment', 'vimString'], synIDattr(synID(line('.'), col('.'), 0), 'name')) >= 0 | continue | endif

        let start = getpos('.')[2]
        let end = searchpos(s:reTest, 'We')[1]
        let tests[getline('.')[start-1 : end-1]] = 0
    endwhile

    " Open test data
    if exists('b:testFile')
        exe "silent e files/".b:testFile
        let openFile = 1
    endif

    " Run tests
    for fname in keys(tests)
        " Position the cursor on //*TestName* comment
        call search('\V//*'.substitute(fname, 'g:Test', '', '').'*', 'w')

        let Test = function(fname)
        try
            call Test()
            let tests[fname] = 1
        catch /Assert/
        endtry
    endfor

    if exists('openFile') | silent! bd | endif


    " Display results
    let success = 0
    let fail = 0
    for fname in keys(tests)
        echo fname
        if tests[fname]
            echo "\tSuccess"
            let success += 1
        else
            echo "\tFailure"
            let fail += 1
        endif
    endfor

    echo len(tests) "tests,"  success "ok,"  fail "failed"
    call setpos('.', origPos)
endfunc

command! RunTests call <SID>RunTests()
