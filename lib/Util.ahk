#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import treesitter { Node }

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
 * @returns {Node} the found node 
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

/**
 * Get the nth argument of a function, or `unset` if it does not exist
 * @param {Node} fnNode 
 * @param {Integer} argIndex 
 * @returns {Node | Unset} 
 */
GetArg(fnNode, argIndex) {
    ;@ahkbuild-ignorebegin
    if !IsInteger(argIndex) || argIndex < 0 {
        throw IndexError("arg index must be a non-negative integer", , argIndex)
    }
    ;@ahkbuild-ignoreend

    argSeq := fnNode.GetChildByFieldName("arguments")
    if argSeq.IsNull || (argSeq.NamedChildCount < argIndex + 1) {
        return unset
    }

    arg := argSeq.GetNamedChild(argIndex)
    return arg.IsNull ? unset : arg
}

FirstNamedChildOfType(parent, type) => 
    parent.GetNamedChildren()
    .FirstOrDefault(child => child.type == type, Node())