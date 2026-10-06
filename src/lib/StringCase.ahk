#Requires AutoHotkey v2.1-alpha.30

/**
 * Syntactic analysis of string case normalization (`StrLower`, `StrUpper`, `StrTitle`), shared by the
 * lints that reason about case-sensitive comparisons.
 */

NORMALIZERS := CaseInsensitiveMap("StrLower", StrLower, "StrUpper", StrUpper, "StrTitle", StrTitle)

/**
 * Collect every case-normalizing call reachable from `node` through concatenation, parentheses, and
 * case-preserving wrappers like `Trim`.
 *
 * @param {Node} node the expression to search
 * @param {Array<Node>} out the array to append to
 * @returns {Array<Node>} `out`, holding the `function_call` nodes of the normalizing calls
 */
export CollectNormalizations(node, out := []) {
    if node.IsNull || node.IsError
        return out

    switch node.type {
        ; Either side, to catch cases like `"on" StrTitle(eventName)`
        case "implicit_concat_operation", "explicit_concat_operation":
            CollectNormalizations(node.GetChildByFieldName("left"), out)
            CollectNormalizations(node.GetChildByFieldName("right"), out)

        case "parenthesized_expression":
            seq := node.GetNamedChild(0)
            if seq.NamedChildCount == 1
                CollectNormalizations(seq.GetNamedChild(0), out)

        case "function_call":
            if NORMALIZERS.Has(CalleeName(node)) && Subject(node)
                out.Push(node)
            else if IsCasePreserving(node)
                CollectNormalizations(Subject(node), out)
    }

    return out
}

/**
 * Classify an expression by what it says about the case of its value.
 *
 * @param {Node} node the expression
 * @returns {Object | String} `{fn, call, exact}` if `node` is a single normalizing call, possibly wrapped;
 *          `{literal}` (the literal's text) if it is a string literal; otherwise an empty string. `exact` is
 *          false when the wrapped result is not itself in the normalized case (`SubStr(StrTitle(x), 2)`).
 */
export ClassifyCase(node) {
    if node.type == "string_literal"
        return { literal: node.text }

    viaSubStr := false
    loop {
        switch node.type {
            case "parenthesized_expression":
                seq := node.GetNamedChild(0)
                if seq.NamedChildCount != 1
                    return ""
                node := seq.GetNamedChild(0)

            case "function_call":
                name := CalleeName(node)
                if NORMALIZERS.Has(name) {
                    fn := NORMALIZERS[name]
                    return { fn: fn, call: node, exact: !(viaSubStr && fn == StrTitle) }
                }
                if !IsCasePreserving(node)
                    return ""
                viaSubStr := viaSubStr || name = "SubStr"
                node := Subject(node)

            default:
                return ""
        }
    }
}

/**
 * Whether rewriting a case-sensitive comparison of `left` and `right` as a case-insensitive one, minus
 * the normalizing calls, keeps its meaning.
 *
 * @returns {String} "safe"; "mismatch" if the comparison's result is fixed as written
 *          (`StrLower(a) == "Bob"`, `StrUpper(a) == StrLower(b)`); or "unknown" if it can't be decided
 */
export CaseEquivalence(left, right) {
    l := ClassifyCase(left)
    r := ClassifyCase(right)
    if !l || !r
        return "unknown"

    if l.HasProp("literal")
        tmp := l, l := r, r := tmp   ; normalized side first
    if !l.HasProp("fn") || !l.exact
        return "unknown"

    if r.HasProp("fn") {
        if !r.exact
            return "unknown"
        if l.fn == r.fn
            return "safe"
        ; Only lower vs. upper is disjoint: `StrTitle("a b") == StrUpper("a b")`
        return l.fn != StrTitle && r.fn != StrTitle ? "mismatch" : "unknown"
    }

    return LiteralHasCase(r.literal, l.fn) ? "safe" : "mismatch"
}

/**
 * Whether a string literal's text is already in the case `fn` produces, so `fn` could have returned it.
 *
 * @param {String} literal the literal's source text, quotes included
 * @param {Func} fn the normalizing function
 */
export LiteralHasCase(literal, fn) {
    ; Escape sequences (`n, `t, ...) stand for characters with no case, but their letters do have one
    text := RegExReplace(SubStr(literal, 2, -1), "``.")
    return fn(text) == text
}

/** Whether a switch's CaseSense argument turns case sensitivity off ("Off", "Locale", false, 0) */
export IsCaseInsensitiveArg(node) {
    switch node.type {
        case "string_literal":  return SubStr(node.text, 2, -1) ~= "i)^(off|locale)$"
        case "boolean_literal": return node.text = "false"
        case "integer_literal": return node.text == "0"
        default:                return false
    }
}

/** The name of the function `call` calls, or an empty string if it isn't called by name */
export CalleeName(call) {
    fn := call.GetChildByFieldName("function")
    return fn.type == "identifier" ? fn.text : ""
}

/** The first argument of `call` (the string being operated on), or 0 if there isn't one */
export Subject(call) {
    args := call.GetChildByFieldName("arguments")
    if args.IsNull || args.NamedChildCount == 0
        return 0
    first := args.GetNamedChild(0)
    return first.type == "empty_arg" ? 0 : first
}

/**
 * Whether `call` returns its first argument's text with case untouched, so a normalization inside it
 * can be hoisted out. `Trim` and friends only qualify without OmitChars, which may be case-sensitive.
 */
IsCasePreserving(call) {
    name := CalleeName(call)
    if name = "SubStr"
        return !!Subject(call)
    if name ~= "i)^(Trim|LTrim|RTrim)$"
        return call.GetChildByFieldName("arguments").NamedChildCount == 1 && !!Subject(call)
    return false
}

CaseInsensitiveMap(pairs*) {
    m := Map()
    m.CaseSense := false
    m.Set(pairs*)
    return m
}
