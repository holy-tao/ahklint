#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/StringCase" { ClassifyCase, CaseEquivalence, LiteralHasCase, IsCaseInsensitiveArg, CalleeName }

/**
 * Report comparisons whose result is fixed by how they're written, which almost always means a bug:
 *
 * - a case-normalized string compared case-sensitively with something it can never equal
 *   (`StrLower(name) == "Bob"`), including `case` labels of a case-sensitive `switch`
 * - a variable compared with itself (`x == x`)
 * - two constants (`"a" == "a"`, `2 == 3`), or a relational comparison of constants that always throws
 * - a value that is never negative compared with a negative number or zero (`InStr(s, "x") == -1`,
 *   `arr.Length < 0.0`)
 */
class ConstantComparison {
    static meta => {
        id:          "constant-comparison",
        title:       "Constant Comparison",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  []
    }

    /** Built-in functions that never return a negative number, keyed by name */
    static NON_NEGATIVE_FUNCS := ConstantComparison.CaseInsensitiveMap(
        "StrLen", "", "InStr", "0 when the substring isn't found", "RegExMatch", "0 when there is no match")

    /** Properties of built-in types that are never negative (Array.Length, Map.Count, ...) */
    static NON_NEGATIVE_PROPS := ConstantComparison.CaseInsensitiveMap("Length", "", "Count", "")

    __New(linter) {
        linter.OnEnter(["equality_operation", "inequality_operation"], this.CheckCase.Bind(this))
        linter.OnEnter(["equality_operation", "inequality_operation", "relational_operation"],
            this.CheckOperands.Bind(this))
        linter.OnEnter("switch_statement", this.CheckSwitch.Bind(this))
    }

    /** `StrLower(a) == "Bob"`, `StrUpper(a) !== StrLower(b)` */
    CheckCase(linter, node) {
        op := node.GetChildByFieldName("operator").type
        if op != "==" && op != "!=="
            return

        left := node.GetChildByFieldName("left")
        right := node.GetChildByFieldName("right")
        if CaseEquivalence(left, right) != "mismatch"
            return

        result := op == "==" ? "false" : "true"
        l := ClassifyCase(left)
        r := ClassifyCase(right)

        if l.HasProp("fn") && r.HasProp("fn") {
            message := Format("This comparison is always {1} unless neither string contains letters: ``{2}`` and "
                . "``{3}`` never return the same letters", result, CalleeName(l.call), CalleeName(r.call))
        } else {
            normalized := l.HasProp("fn") ? l : r
            literal := l.HasProp("literal") ? l : r
            message := Format("This comparison is always {1}: ``{2}`` can never return {3}",
                result, CalleeName(normalized.call), literal.literal)
        }

        linter.Report(ConstantComparison.meta, node, message)
    }

    /** `x == x`, `StrLen(s) < 0`, `InStr(s, "x") == -1` */
    CheckOperands(linter, node) {
        left := node.GetChildByFieldName("left")
        right := node.GetChildByFieldName("right")
        op := node.GetChildByFieldName("operator").type

        if left.type == "identifier" && right.type == "identifier" && left.text = right.text {
            result := op ~= "^(=|==|<=|>=)$" ? "true" : "false"
            message := Format("Comparing ``{1}`` with itself is always {2}", left.text, result)
            linter.Report(ConstantComparison.meta, node, message)
            return
        }

        ; `"a" == "a"`, `2 == 3`: evaluate it with the same operator the script would use
        leftConst := ConstantComparison.ConstantValue(left)
        rightConst := ConstantComparison.ConstantValue(right)
        if leftConst && rightConst {
            try {
                result := ConstantComparison.Compare(op, leftConst.value, rightConst.value) ? "true" : "false"
                message := Format("This comparison is always {1}: both sides are constants", result)
            } catch TypeError {
                message := Format("This comparison always throws a TypeError: ``{1}`` only compares numbers", op)
            }
            linter.Report(ConstantComparison.meta, node, message)
            return
        }

        ; Put the non-negative value on the left, flipping the operator to match
        if !(what := ConstantComparison.NonNegative(left)) {
            if !(what := ConstantComparison.NonNegative(right))
                return
            tmp := left, left := right, right := tmp
            tmp := leftConst, leftConst := rightConst, rightConst := tmp
            op := Map("<", ">", ">", "<", "<=", ">=", ">=", "<=").Get(op, op)
        }

        if !rightConst || !IsNumber(rightConst.value)
            return
        bound := Number(rightConst.value)
        if bound > 0
            return

        ; With value >= 0 and bound <= 0
        switch op {
            case "=", "==":   result := bound < 0 ? "false" : ""
            case "!=", "!==": result := bound < 0 ? "true" : ""
            case "<":         result := "false"
            case ">=":        result := "true"
            case "<=":        result := bound < 0 ? "false" : ""
            case ">":         result := bound < 0 ? "true" : ""
        }
        if result == ""
            return

        message := Format("This comparison is always {1}: {2} is never negative", result, what.name)
        if what.hint
            message .= Format(" (it returns {1})", what.hint)
        linter.Report(ConstantComparison.meta, node, message)
    }

    /** `case` labels a case-sensitive `switch StrLower(x)` can never reach */
    CheckSwitch(linter, node) {
        head := node.GetChildByFieldName("head")
        if head.IsNull
            return

        caseSense := node.GetChildByFieldName("case_sense")
        if !caseSense.IsNull && IsCaseInsensitiveArg(caseSense)
            return

        side := ClassifyCase(head)
        if !side || !side.HasProp("fn") || !side.exact
            return

        body := node.GetChildByFieldName("body")
        loop body.NamedChildCount {
            clause := body.GetNamedChild(A_Index - 1)
            if clause.type != "case_clause"
                continue

            for value in clause.GetChildrenByFieldName("value") {
                if value.type == "string_literal" && !LiteralHasCase(value.text, side.fn) {
                    message := Format("This case never matches: ``{1}`` can never return {2}",
                        CalleeName(side.call), value.text)
                    linter.Report(ConstantComparison.meta, value, message)
                }
            }
        }
    }

    /**
     * If `node` is a call or property known never to be negative, describe it.
     *
     * @returns {Object | String} `{name, hint}` for use in a message, or an empty string
     */
    static NonNegative(node) {
        switch node.type {
            case "function_call":
                name := CalleeName(node)
                if this.NON_NEGATIVE_FUNCS.Has(name)
                    return { name: "``" name "``", hint: this.NON_NEGATIVE_FUNCS[name] }

            case "member_access":
                member := node.GetChildByFieldName("member")
                if member.type == "identifier" && this.NON_NEGATIVE_PROPS.Has(member.text)
                    return { name: "``." member.text "``", hint: "" }
        }
        return ""
    }

    /**
     * Evaluate a constant expression: a literal, possibly parenthesized or under a unary operator (`-1`,
     * `!0`). Values have the type the script would see at runtime - a quoted literal is a String even if
     * it looks numeric - so comparing them here behaves as the script would.
     *
     * @returns {Object | String} `{value}`, or an empty string if `node` isn't a constant
     */
    static ConstantValue(node) {
        try switch node.type {
            case "integer_literal", "hex_literal": return { value: Integer(node.text) }
            case "float_literal":                  return { value: Float(node.text) }
            case "boolean_literal":                return { value: node.text = "true" }
            case "string_literal":                 return { value: this.DecodeString(node.text) }

            case "parenthesized_expression":
                seq := node.GetNamedChild(0)
                return seq.NamedChildCount == 1 ? this.ConstantValue(seq.GetNamedChild(0)) : ""

            case "prefix_operation":
                if !(operand := this.ConstantValue(node.GetChildByFieldName("operand")))
                    return ""
                switch node.GetChildByFieldName("operator").type {
                    case "-": return { value: -operand.value }
                    case "+": return { value: +operand.value }
                    case "!": return { value: !operand.value }
                    case "~": return { value: ~operand.value }
                }
        }
        catch TypeError
            return ""   ; e.g. `-"abc"`; that throws, but it isn't a comparison problem

        return ""
    }

    /** Compare two values with an AHK comparison operator */
    static Compare(op, a, b) {
        switch op {
            case "=":   return a = b
            case "==":  return a == b
            case "!=":  return a != b
            case "!==": return a !== b
            case "<":   return a < b
            case ">":   return a > b
            case "<=":  return a <= b
            case ">=":  return a >= b
        }
    }

    /** The value of a quoted string literal, with its escape sequences decoded */
    static DecodeString(literal) {
        static escapes := Map("n", "`n", "r", "`r", "t", "`t", "b", "`b", "v", "`v", "a", "`a", "f", "`f", "s", " ")

        text := SubStr(literal, 2, -1)
        out := "", pos := 1
        while found := InStr(text, "``", true, pos) {
            char := SubStr(text, found + 1, 1)
            out .= SubStr(text, pos, found - pos) . escapes.Get(char, char)   ; `` `" `; ... are the char itself
            pos := found + 2
        }
        return out . SubStr(text, pos)
    }

    static CaseInsensitiveMap(pairs*) {
        m := Map()
        m.CaseSense := false
        m.Set(pairs*)
        return m
    }
}
