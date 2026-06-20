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