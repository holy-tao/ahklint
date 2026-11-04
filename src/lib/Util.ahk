#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "treesitter" { Node }

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
    while current.NamedChildCount == 1 {
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
 * Find the first named child of `node` with type `type`. Returns a null node if
 * no such child is found
 * @returns {Node} the found node
 */
TryGetChildOfType(parent, type) {
    static NULL := Node()
    loop parent.NamedChildCount {
        child := parent.GetNamedChild(A_Index - 1)
        if child.Type == type
            return child
    }

    return NULL
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

FirstNamedChildOfType(parent, type) => TryGetChildOfType(parent, type)

/** Whether the given node is a comment of any kind */
IsComment(node) => RegExMatch(node.type, "S)^(line_comment|block_comment|directive_comment)$")

/** Whether the given node is a binary expression of any kind */
IsBinaryExpr(node) => RegExMatch(node.type, "S)^(additive_operation|multiplicative_operation|relational_operation|equality_operation|inequality_operation|regex_match_operation|type_check_operation|logical_and_operation|logical_or_operation|bitwise_and_operation|bitwise_xor_operation|bitwise_or_operation|bitshift_operation|explicit_concat_operation|exponent_operation|or_maybe_operation|implicit_concat_operation)$")

IsUnaryExpr(node) => node.type = "prefix_operation"

IsLiteralPrimitive(node) => RegExMatch(node.type, "S)^(integer_literal|float_literal|hex_literal|boolean_literal|string_literal|multiline_string_literal)$")

/**
 * Check whether `expr` is constant; that is, consists entirely of constant primitives
 * and binary operations over those primitives.
 *
 * Calls are only constant if `isPureCallee` is given: a call `Fn(args*)` is constant when its
 * callee is a bare identifier that `isPureCallee` accepts and every argument is constant.
 *
 * @param {Node} expr the node to check
 * @param {Func} isPureCallee optional; `(identifier) => Boolean`, whether calling the function
 *        that identifier names always gives the same result for the same constant arguments
 * @returns {Integer} 1 if the expression is constant, 0 if not
 */
IsConstExpr(expr, isPureCallee?) {
    ;@ahkbuild-ignorebegin
    if !(expr is Node)
        throw TypeError("Expected a Node but got a(n) " type(expr), , expr)
    if expr.IsNull
        throw TypeError("``expr`` cannot be a null Node!")
    ;@ahkbuild-ignoreend

    switch {
        case IsBinaryExpr(expr):
            return IsConstExpr(expr.GetChildByFieldName("left"), isPureCallee?)
                && IsConstExpr(expr.GetChildByFieldName("right"), isPureCallee?)
        case IsUnaryExpr(expr):
            return IsConstExpr(expr.GetChildByFieldName("operand"), isPureCallee?)
        case expr.type = "parenthesized_expression":
            ; drill through
            seq := expr.GetNamedChild(0)
            if seq.NamedChildCount > 1
                return false
            return IsConstExpr(seq.GetNamedChild(0), isPureCallee?)
        case expr.type = "function_call":
            callee := expr.GetChildByFieldName("function")
            if !IsSet(isPureCallee) || callee.type != "identifier" || !isPureCallee(callee)
                return false
            args := expr.GetChildByFieldName("arguments")
            if args.IsNull
                return true
            ; An omitted argument (`Fn(a,, b)`) is fine; a spread (`Fn(arr*)`) is not constant
            loop args.NamedChildCount {
                arg := args.GetNamedChild(A_Index - 1)
                if arg.type != "empty_arg" && !IsConstExpr(arg, isPureCallee)
                    return false
            }
            return true
        default:
            return IsLiteralPrimitive(expr)
    }
}

/**
 * Joins strings with `delimiter`.
 * @param {String} delimiter The delimiter
 * @param {String} strs Zero or more strings to join with `delimiter`
 */
StrJoin(delimiter, strs*) {
    outStr := "", VarSetStrCapacity(&outStr, 1024)
    for str in strs {
        outStr .= String(str)
        if A_Index < strs.Length
            outStr .= delimiter
    }

    return outStr
}
