" Author: Bassam JABBOUR
" Description: Build dependency graphs between groups of files based on
" #include statements. Nodes in the graph either represent files
" (resolved includes), in which case they can have children, or grepped
" data, in which case they are located at a leaf. Children of a node are
" ordered the same way they appear in the parent file.

" === Node =============================================================

" Graph node constructor.
"
" @param idx the index of this node among its siblings; this will make
" walking through the graph easier
" @param text the text this node holds (filename/using-instruction)
"
" @return A node has the following fields:
" - idx: see @param idx
" - text: see @param data
" - parent: a reference to the parent node.
" - children: a list of child nodes.
" - path: a list of file positions (objects with 'file' and 'line' keys)
"   retracing the hops from the top of the tree (in a graph) to that
"   node, through includes. For every entry in the list, the file is
"   visible from the current node up to the specified line.
" - addChildren(): see AddChildren()
"
func! omnicpp#graph#Node(idx,text)
    return {'idx' : a:idx, 'text' : a:text, 'parent' : {}, 'children' : [], 'path' : [],
                \ 'addChildren' : function('omnicpp#graph#AddChildren')}
endfunc

" Given a list of entries, create a node for each one, and set up those
" nodes as children to the current object.
"
" @param children Node's children, as returned by utils#Grep()
"
func! omnicpp#graph#AddChildren(children) dict
    for idx in range(len(a:children))
        let node = omnicpp#graph#Node(idx, a:children[idx].text)
        let node.parent = self
        let node.path = self.path + [{'file' : self.text, 'line' : a:children[idx].line}]
        call add(self.children, node)
    endfor
endfunc

" === Graph ============================================================

" Graph constructor.
"
" @param root the data the root node holds
" @return A graph has the following entries:
" - root: the node at the top of the graph's hierarchy.
" - current: the node we are currently at when walking through the
"   graph (initially the root node).
" - complete: names of nodes that were completely parsed when walking
"   through the graph (no children left).
" - next(): see Next()
" - isVisited(): see IsVisited()
" - filter(): a predicate that is applied to nodes when walking through
"   the graph; only nodes that pass the test are eligible to be selected
"   through next(). Initialized to FilterIncludes().
"
func! omnicpp#graph#Graph(root)
    let rootNode = omnicpp#graph#Node(0,a:root)

    return {'root' : rootNode, 'current' : rootNode, 'complete' : [],
                \ 'next' : function('omnicpp#graph#Next'),
                \ 'isVisited' : function('omnicpp#graph#IsVisited'),
                \ 'filter' : function('omnicpp#graph#FilterIncludes')}
endfunc

" Walk through the graph, iterator-style. When standing on a given node,
" we first look for children; if none, we rewind the inheritance tree,
" looking for subsequent siblings at every level, until we reach the
" root node. The 'current' attribute is only updated if the next node is
" actually found.
"
" The valid nodes are those that verify the filter() predicate; only
" those are considered when searching, and non-valid nodes are simply
" ignored.
"
" @return Next node, or an empty object if none.
"
func! omnicpp#graph#Next() dict
    let nextNode = {}

    " The node we are currently at
    let current = self.current
    " The child node to start at when looking for valid children
    let childIdx = 0
    " Search back to the top of the graph
    while !empty(current)
        " Look for valid child nodes
        if len(current.children) > childIdx
            for child in current.children[childIdx :]
                if self.filter(child)
                    let nextNode = child
                    break
                endif
            endfor
        endif

        " No valid children: rewind one level
        if empty(nextNode)
            call add(self.complete, current.text)
            let childIdx = current.idx + 1
            let current = current.parent
        else
            let self.current = nextNode
            break
        endif
    endwhile

    return nextNode
endfunc

" A predicate for filtering duplicate nodes. A duplicate node appears
" either in the 'complete' list, or along the path leading to the
" current node.
"
" @param node Node to check
" @return 1 if the node is a duplicate, 0 otherwise
"
func! omnicpp#graph#IsVisited(node) dict
    let parsing = map(copy(a:node.path), 'v:val.file')
    return index(self.complete+parsing, a:node.text) >= 0
endfunc

" === Task-specific ====================================================

" A predicate for validating nodes in a parsing graph. A node is valid
" if it is not an include, or otherwise if it has not already been
" visited prior to the current node (includes are parsed only once).
"
" @param node Node to check
" @return 1 for a valid node, 0 otherwise
"
func! omnicpp#graph#FilterIncludes(node) dict
    return a:node.text[0] != '/' || !self.isVisited(a:node)
endfunc
