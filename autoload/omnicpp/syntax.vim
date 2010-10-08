" Author: Bassam JABBOUR
" Description: Syntax elements for C++

"{{{1 Keywords

let g:omnicpp#syntax#KeySpecifier = ['auto', 'register', 'static', 'extern', 'mutable', 'const', 'volatile']
let g:omnicpp#syntax#KeyFunction = ['inline', 'virtual', 'explicit']
let g:omnicpp#syntax#KeyType = ['bool', 'char', 'double', 'float', 'int', 'long', 'short', 'void', 'wchar_t', 'signed', 'unsigned']
let g:omnicpp#syntax#KeyOp = ['and', 'and_eq', 'bitand', 'bitor', 'compl', 'not', 'not_eq', 'or', 'or_eq', 'xor', 'xor_eq']
let g:omnicpp#syntax#KeyMisc = ['asm', 'break', 'case', 'catch', 'class', 'const_cast', 'continue', 'default', 'delete', 'do', 'dynamic_cast', 'else', 'enum', 'export', 'false', 'for', 'friend', 'goto', 'if', 'namespace', 'new', 'operator', 'private', 'protected', 'public', 'reinterpret_cast', 'return', 'sizeof', 'static_cast', 'struct', 'switch', 'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'using', 'while'] 

let g:omnicpp#syntax#Keywords = g:omnicpp#syntax#KeySpecifier + g:omnicpp#syntax#KeyFunction + g:omnicpp#syntax#KeyType + g:omnicpp#syntax#KeyOp + g:omnicpp#syntax#KeyMisc

"{{{1 Operators

" Operators classification.
" Some operators can belong to multiple groups; for example, '+' is a
" composition operator if preceded by an identifier, and a unary
" operator otherwise.

" The following operators delimit two instructions that can be treated
" separately
"
" Returns a bool
let g:omnicpp#syntax#OpComparison = ['==', '!=', '<=', '>=', '<', '>']
" Returns the type of its left member
let g:omnicpp#syntax#OpComposition = ['+', '-', '*', '/', '%', '&', '|', '^', '<<', '>>', '&&', '||']
let g:omnicpp#syntax#OpAssign = ['=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=']
" All splitting operators group
let g:omnicpp#syntax#OpSplitG = g:omnicpp#syntax#OpComparison + g:omnicpp#syntax#OpComposition + g:omnicpp#syntax#OpAssign + [',', '?', ':', ';', '{', '}']

" The following operators are part of the instruction flow
"
" Returns the type of its attached identifier
let g:omnicpp#syntax#OpPreUnary = ['+', '-', '!', '~']
let g:omnicpp#syntax#OpMixUnary = ['++', '--']
" The right hand is a member of the left hand
let g:omnicpp#syntax#OpMember = ['->', '.', '->*', '.*', '::']
" If preceded by a type, acts as a type modifier;
" else as a unary operator with special return type.
let g:omnicpp#syntax#OpPointer = ['*', '&']
" All non-splitting operators group
let g:omnicpp#syntax#OpTiedG = g:omnicpp#syntax#OpPreUnary + g:omnicpp#syntax#OpMixUnary + g:omnicpp#syntax#OpMember + g:omnicpp#syntax#OpPointer + ['[', ']', '(', ')']

" Sorted list, longest operators first
function! s:CmpLongestFirst(str1, str2)
    return len(a:str1) == len(a:str2) ? 0 : len(a:str2) > len(a:str1) ? 1 : -1
endfunc
" All operators
let g:omnicpp#syntax#Operators = sort(g:omnicpp#syntax#OpTiedG + g:omnicpp#syntax#OpSplitG, "s:CmpLongestFirst")


"{{{1 Regexes
" Note: all regexes must be preceded by either (\v, \m, \M or \V) for
" any aggregated regexp to work properly

" ORing keywords
let g:omnicpp#syntax#reKeyword = '\v\C<'.join(g:omnicpp#syntax#Keywords, '>|<').'>'
" ORing operators
let g:omnicpp#syntax#reOperator = '\V'.join(g:omnicpp#syntax#Operators, '\|')

" The digits regex first matches against hex numbers, then floating
" numbers, and finally plain integers
let g:omnicpp#syntax#reDigit = '\v-=(0x\x+[UL]=|(\d+.\d*|.\d+)(e-=\d+)=[fFlL]=|\d+[UL]=)'
" Valid C++ identifiers (allows the $ character)
let g:omnicpp#syntax#reIdSimple = '\v<\h(\w|\d|\$)*>'
"" Excluding keywords version
let g:omnicpp#syntax#reIdFull = '\v('.g:omnicpp#syntax#reKeyword.')@!'.g:omnicpp#syntax#reIdSimple

" vim: fdm=marker
