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
" @param data the data this node holds (filename/using-instruction)
"
" @return A node has the following fields:
" - idx: see @param idx
" - data: see @param data
" - parent: a reference to the parent node.
" - children: a list of child nodes.
" - addChildren(): see graph#AddChildren()
"
func! omnicpp#graph#Node(idx,data)
    return {'idx' : a:idx, 'data' : a:data, 'parent' : {}, 'children' : [],
                \ 'addChildren' : function('omnicpp#graph#AddChildren')}
endfunc

" Given a list of entries, create a node for each one, and set up those
" nodes as children to the current object.
"
" @param children list of node data
"
func! omnicpp#graph#AddChildren(children) dict
    for idx in range(len(a:children))
        let node = omnicpp#graph#Node(idx, a:children[idx])
        let node.parent = self
        call add(self.children, node)
    endfor
endfunc

" === Graph ============================================================

" Graph constructor.
"
" @param root the data the root node holds
" @return A graph has the following entries:
" - root: the node at the top of the graph's hierarchy.
" - current: internal variable; the node we are currently at when
"   walking through the graph.
" - next(): see graph#Next()
"
func! omnicpp#graph#Graph(root)
    let rootNode = omnicpp#graph#Node(0, a:root)

    return {'root' : rootNode,
                \ 'current' : {},
                \ 'next' : function('omnicpp#graph#Next')}
endfunc

" Walk through the graph, iterator-style. When standing on a given node,
" we first look for children; if none, we rewind the inheritance tree,
" looking for subsequent siblings at every level, until we reach the
" root node. The 'current' attribute is only updated if the next node is
" actually found.
"
" @return Next node, or an empty object if none.
"
func! omnicpp#graph#Next() dict
    let nextNode = {}

    if empty(self.current)
        " First invocation, graph with only a root node
        let nextNode = self.root

    elseif !empty(self.current.children)
        " First look for child nodes
        let nextNode = self.current.children[0]

    else
        " We will only update the 'current' field if the next node
        " exists
        let current = self.current
        " Keep rewinding until we reach the root node
        while current != self.root
            " Look for subsequent nodes at the same level (subsequent
            " data in the same parent file)
            if current.idx < len(current.parent.children)-1
                let nextNode = current.parent.children[current.idx+1]
                break
            " No adjacent nodes: rewind one level
            else
                let current = current.parent
            endif
        endwhile
    endif

    if !empty(nextNode) | let self.current = nextNode | endif

    return nextNode
endfunc
