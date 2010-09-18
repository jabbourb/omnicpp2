" Author: Bassam JABBOUR
" Description: Syntax elements for C++

"{{{1 Keywords

let g:omnicpp#syntax#Keywords = ['asm', 'auto', 'bool', 'break', 'case', 'catch', 'char', 'class', 'const', 'const_cast', 'continue', 'default', 'delete', 'do', 'double', 'dynamic_cast', 'else', 'enum', 'explicit', 'export', 'extern', 'false', 'float', 'for', 'friend', 'goto', 'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 'operator', 'private', 'protected', 'public', 'register', 'reinterpret_cast', 'return', 'short', 'signed', 'sizeof', 'static', 'static_cast', 'struct', 'switch', 'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'and', 'and_eq', 'bitand', 'bitor', 'compl', 'not', 'not_eq', 'or', 'or_eq', 'xor', 'xor_eq']


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

" vim: fdm=marker
