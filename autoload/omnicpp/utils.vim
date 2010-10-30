" Author: Bassam Jabbour
" Description: Utility functions for OmniCpp2


" Scan a string backwards, and find the opening element of an
" (open,close) pair encompassing the end of the string. This is similar
" to searchpair() (but for strings).
"
" @param string the string to scan
" @param open the opening character
" @param close the closing character
"
" @return the index of the opening character, -1 if none
"
func! omnicpp#utils#SearchPairBack(string, open, close)
    let counter = 0
    for idx in reverse(range(len(a:string)))
        if a:string[idx] == a:open
            if counter==0
                return idx
            else
                let counter -= 1
            endif
        elseif a:string[idx] == a:close
            let counter += 1
        endif
    endfor
    return -1
endfunc

func! omnicpp#utils#ParentDir(file)
    return '/'.join(split(a:file,'/')[:-2],'/')
endfunc

