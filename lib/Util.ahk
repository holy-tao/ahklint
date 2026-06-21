#Requires AutoHotkey v2.1-alpha.30

/**
 * Given a tree-sitter node, return its first named child which has more than one
 * child node or which is a leaf node. If the node itself has multiple children
 * or is a leaf, returns it unchanged.
 * 
 * You can use this fuction to drill through e.g. expression sequences with exactly
 * one expression, to go from `(("string"))` -> to a `string_literal` node.
 * 
 * @param {TreeSitter.Node} node the node 
 * @returns {TreeSitter.Node} 
 */
FlattenNode(node) {
    current := node
    while current.NamedChildCount > 1 {
        current := current.GetNamedChild(0)
    }
    return current
}

/**
 * Find the first named child of `node` with type `type`. Throws an error
 * if no such child is found
 * @returns {TreeSitter.Node} the found node 
 */
GetChildOfType(node, type) {
    loop node.NamedChildCount {
        child := node.GetNamedChild(A_Index - 1)
        if child.Type == type
            return child
    }

    msg := Format("Node of type '{1}' has no child of type '{2}'", node.Type, type)
    throw IndexError(msg, , node.NodeString)
}