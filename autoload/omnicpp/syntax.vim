" Author: Bassam JABBOUR
" Description: Syntax elements for C++

"{{{1 Keywords

let g:CppKeywords = ['asm', 'auto', 'bool', 'break', 'case', 'catch', 'char', 'class', 'const', 'const_cast', 'continue', 'default', 'delete', 'do', 'double', 'dynamic_cast', 'else', 'enum', 'explicit', 'export', 'extern', 'false', 'float', 'for', 'friend', 'goto', 'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 'operator', 'private', 'protected', 'public', 'register', 'reinterpret_cast', 'return', 'short', 'signed', 'sizeof', 'static', 'static_cast', 'struct', 'switch', 'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'and', 'and_eq', 'bitand', 'bitor', 'compl', 'not', 'not_eq', 'or', 'or_eq', 'xor', 'xor_eq']


"{{{1 Operators

" Operators classification.
" Some operators can belong to multiple groups; for example, '+' is a
" composition operator if preceded by an identifier, and a unary
" operator otherwise.

" The following operators delimit two instructions that can be treated
" separately
"
" Returns a bool
let g:CppOpComparison = ['==', '!=', '<=', '>=', '<', '>']
" Returns the type of its left member
let g:CppOpComposition = ['+', '-', '*', '/', '%', '&', '|', '^', '<<', '>>', '&&', '||']
let g:CppOpAssign = ['=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=']
" All splitting operators group
let g:CppOpSplitG = g:CppOpComparison + g:CppOpComposition + g:CppOpAssign + [',', '?', ':', ';', '{', '}']

" The following operators are part of the instruction flow
"
" Returns the type of its attached identifier
let g:CppOpPreUnary = ['+', '-', '!', '~']
let g:CppOpMixUnary = ['++', '--']
" The right hand is a member of the left hand
let g:CppOpMember = ['->', '.', '->*', '.*', '::']
" If preceded by a type, acts as a type modifier;
" else as a unary operator with special return type.
let g:CppOpPointer = ['*', '&']
" All non-splitting operators group
let g:CppOpTiedG = g:CppOpPreUnary + g:CppOpMixUnary + g:CppOpMember + g:CppOpPointer + ['[', ']', '(', ')']

" Sorted list, longest operators first
function! s:CmpLongestFirst(str1, str2)
    return len(a:str1) == len(a:str2) ? 0 : len(a:str2) > len(a:str1) ? 1 : -1
endfunc
" All operators
let g:CppOperators = sort(g:CppOpTiedG + g:CppOpSplitG, "s:CmpLongestFirst")

" vim: fdm=marker
