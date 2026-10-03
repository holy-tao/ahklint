#Requires AutoHotkey v2.1-alpha.30

/**
 * The runtime values of string literals, shared by the lints that evaluate constants.
 */

/**
 * The value of a string literal node.
 *
 * @param {Node} node a `string_literal` or `multiline_string_literal`
 * @returns {Object | String} `{value}`, or an empty string if the value can't be worked out: `node` isn't
 *          a string literal, or it is a continuation section with options
 */
export StringValue(node) {
    switch node.type {
        case "string_literal":
            return { value: DecodeString(node.text) }
        case "multiline_string_literal":
            return DecodeContinuation(node.text)
        default:
            return ""
    }
}

/** The value of a quoted string literal, with its escape sequences decoded */
export DecodeString(literal) {
    return Unescape(SubStr(literal, 2, -1))
}

/**
 * The value of a quoted continuation section. Only the default behavior is modelled: indentation of the
 * first line is removed from every line, trailing whitespace is dropped, and lines are joined with `n.
 *
 * ;TODO: model continuations with options too
 *
 * @param {String} literal the literal's source text, from the opening quote to the closing one
 * @returns {Object | String} `{value}`, or an empty string for a section with options (`Join`, `LTrim0`,
 *          `Comments`, ...), which change how its lines are read
 */
DecodeContinuation(literal) {
    lines := StrSplit(literal, "`n", "`r")
    if lines.Length < 3
        return ""

    quote := SubStr(literal, 1, 1)
    if Trim(lines[1], " `t") != quote || Trim(lines[2], " `t") != "(" || Trim(lines[-1], " `t") != ")" quote
        return ""

    lines.RemoveAt(1, 2)
    lines.Pop()
    if lines.Length == 0
        return { value: "" }

    RegExMatch(lines[1], "^[ \t]*", &indent)
    value := ""
    for line in lines {
        if indent[0] != "" && InStr(line, indent[0], true) == 1
            line := SubStr(line, StrLen(indent[0]) + 1)
        value .= (A_Index > 1 ? "`n" : "") . RTrim(line, " `t")
    }
    return { value: Unescape(value) }
}

/** Decode the escape sequences in the body of a string literal */
Unescape(text) {
    static escapes := Map("n", "`n", "r", "`r", "t", "`t", "b", "`b", "v", "`v", "a", "`a", "f", "`f", "s", " ")

    out := "", pos := 1
    while found := InStr(text, "``", true, pos) {
        char := SubStr(text, found + 1, 1)
        out .= SubStr(text, pos, found - pos) . escapes.Get(char, char)   ; `` `" `; ... are the char itself
        pos := found + 2
    }
    return out . SubStr(text, pos)
}
