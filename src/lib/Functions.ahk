#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "Util" { TryGetChildOfType }

FUNCTION_NODES := [
    "function_declaration",
    "method_declaration",
    "function_expression"
]

/**
 * Given a function_declaration node, collects all parameters into a map of names to node objects
 *
 * @param {Node} node the node
 * @returns {Map<String, Node>} map of node names to nodes for params
 */
CollectParams(node) {
    ;@ahkbuild-ignorebegin
    if !FUNCTION_NODES.Any((name) => node.type = name)
        throw TypeError("Expected a function node " String(FUNCTION_NODES), , node.type)
    ;@ahkbuild-ignoreend

    params := Map()
    params.CaseSense := "off"

    paramSeq := TryGetChildOfType(node.GetChildByFieldName("head"), "param_sequence")
    if paramSeq.IsNull
        return params

    current := paramSeq.GetNamedChild(0)

    while !current.IsNull {
        params[ExtractName(current)] := current
        current := current.NextNamedSibling
    }

    return params

    ; Helper to extract the name of a _param node
    ExtractName(node) {
        switch node.Type {
            case "identifier":
                return node.Text
            case "optional_param", "default_param", "variadic_param":
                return node.GetChildByFieldName("name").Text
            case "byref_param":
                return ExtractName(node.GetChildByFieldName("param"))
            default:
                throw ValueError("Unknown node type " node.Type)
        }
    }
}
