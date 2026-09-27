#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

/**
 * Warn for string equality comparisons and switch statements that normalize the case of a string in order
 * to do a case-insensitive comparison. AHK has built-in operators for this that will reduce code complexity
 * and marginally improve performance.
 *
 * Finding a normalization and fixing it are kept separate: `Collect` returns the normalizing call nodes
 * themselves, however deeply they are wrapped, and each one is fixed by the same two patches (remove
 * `StrLower(` and the closing `)`) regardless of what surrounds it.
 */
class CaseNormalization {
    static meta => {
        id:          "case-normalization",
        title:       "Unnecessary String Case Normalization",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",  ; `=` folds only ASCII letters, StrLower & co. fold per locale
        recommended: true,
        references:  []
    }

    /** Functions that normalize case, keyed by name (case-insensitively, like AHK's function names) */
    static NORMALIZERS := CaseNormalization.CaseInsensitiveMap(
        "StrLower", StrLower,
        "StrUpper", StrUpper,
        "StrTitle", StrTitle
    )

    __New(linter) {
        linter.OnEnter(["equality_operation", "inequality_operation"], this.CheckComparison.Bind(this))
        linter.OnEnter("switch_statement", this.CheckSwitch.Bind(this))
    }

    CheckComparison(linter, node) {
        left := node.GetChildByFieldName("left")
        right := node.GetChildByFieldName("right")

        calls := CaseNormalization.Collect(left)
        CaseNormalization.Collect(right, calls)
        if !calls.Length
            return

        fnName := CaseNormalization.CalleeName(calls[1])
        op := node.GetChildByFieldName("operator")

        ; Already case-insensitive: the normalization never changes the result
        if op.type == "=" || op.type == "!=" {
            message := Format("Calling ``{1}`` is unnecessary here; the ``{2}`` operator is case-insensitive",
                fnName, op.type)
            linter.Report(CaseNormalization.meta, node, message, CaseNormalization.RemoveCalls(calls))
            return
        }

        insensitiveOp := op.type == "==" ? "=" : "!="
        message := Format("Use the case-insensitive comparison operator ``{1}`` instead of calling ``{2}``",
            insensitiveOp, fnName)

        switch CaseNormalization.Equivalence(left, right) {
            case "safe":
                fixes := CaseNormalization.RemoveCalls(calls)
                fixes.Push(Fix.To(op, insensitiveOp))
                linter.Report(CaseNormalization.meta, node, message, fixes)

            ; e.g. `StrLower(a) == "Bob"` - the comparison is constant, which is a bug rather than a
            ; simplification, and suggesting `=` would silently change what the code does
            case "mismatch":
                return

            default:
                linter.Report(CaseNormalization.meta, node, message)
        }
    }

    CheckSwitch(linter, node) {
        head := node.GetChildByFieldName("head")
        if head.IsNull
            return

        calls := CaseNormalization.Collect(head)
        if !calls.Length
            return

        fnName := CaseNormalization.CalleeName(calls[1])
        caseSense := node.GetChildByFieldName("case_sense")

        if !caseSense.IsNull && CaseNormalization.IsCaseInsensitiveArg(caseSense) {
            message := Format("Calling ``{1}`` is unnecessary here; the switch is already case-insensitive", fnName)
            linter.Report(CaseNormalization.meta, head, message, CaseNormalization.RemoveCalls(calls))
            return
        }

        message := Format("Set the switch's CaseSense to {1} instead of calling ``{2}``", '"Off"', fnName)

        side := CaseNormalization.ClassifySide(head)
        if side && side.HasProp("fn") && side.exact && CaseNormalization.LabelsMatch(node, side.fn) {
            fixes := CaseNormalization.RemoveCalls(calls)
            fixes.Push(caseSense.IsNull
                ? Fix.Insert(head.endByte, ', "Off"')
                : Fix.To(caseSense, '"Off"'))
            linter.Report(CaseNormalization.meta, head, message, fixes)
        } else {
            linter.Report(CaseNormalization.meta, head, message)
        }
    }

    /**
     * Collect every case-normalizing call reachable from `node` through concatenation, parentheses, and
     * case-preserving wrappers like `Trim`.
     *
     * @param {Node} node the expression to search
     * @param {Array<Node>} out the array to append to
     * @returns {Array<Node>} `out`, holding the `function_call` nodes of the normalizing calls
     */
    static Collect(node, out := []) {
        if node.IsNull || node.IsError
            return out

        switch node.type {
            ; Either side, to catch cases like `"on" StrTitle(eventName)`
            case "implicit_concat_operation", "explicit_concat_operation":
                this.Collect(node.GetChildByFieldName("left"), out)
                this.Collect(node.GetChildByFieldName("right"), out)

            case "parenthesized_expression":
                seq := node.GetNamedChild(0)
                if seq.NamedChildCount == 1
                    this.Collect(seq.GetNamedChild(0), out)

            case "function_call":
                if this.NORMALIZERS.Has(this.CalleeName(node)) && this.Subject(node)
                    out.Push(node)
                else if this.IsCasePreserving(node)
                    this.Collect(this.Subject(node), out)
        }

        return out
    }

    /**
     * Classify one side of a comparison for deciding whether dropping its normalization is safe.
     *
     * @param {Node} node the expression
     * @returns {Object | String} `{fn, exact}` if `node` is a single normalizing call, possibly wrapped;
     *          `{literal}` if it is a string literal; otherwise an empty string. `exact` is false when the
     *          wrapped result is not itself in the normalized case (`SubStr(StrTitle(x), 2)`).
     */
    static ClassifySide(node) {
        if node.type == "string_literal"
            return { literal: this.LiteralContent(node) }

        viaSubStr := false
        loop {
            switch node.type {
                case "parenthesized_expression":
                    seq := node.GetNamedChild(0)
                    if seq.NamedChildCount != 1
                        return ""
                    node := seq.GetNamedChild(0)

                case "function_call":
                    name := this.CalleeName(node)
                    if this.NORMALIZERS.Has(name) {
                        fn := this.NORMALIZERS[name]
                        return { fn: fn, exact: !(viaSubStr && fn == StrTitle) }
                    }
                    if !this.IsCasePreserving(node)
                        return ""
                    viaSubStr := viaSubStr || name = "SubStr"
                    node := this.Subject(node)

                default:
                    return ""
            }
        }
    }

    /**
     * Whether rewriting a case-sensitive comparison of `left` and `right` as a case-insensitive one, minus
     * the normalizing calls, keeps its meaning.
     *
     * @returns {String} "safe"; "mismatch" if the comparison is constant as written (`StrLower(a) == "Bob"`,
     *          `StrUpper(a) == StrLower(b)`); or "unknown" if it can't be decided syntactically
     */
    static Equivalence(left, right) {
        l := this.ClassifySide(left)
        r := this.ClassifySide(right)
        if !l || !r
            return "unknown"

        if l.HasProp("literal")
            tmp := l, l := r, r := tmp   ; normalized side first
        if !l.HasProp("fn") || !l.exact
            return "unknown"

        if r.HasProp("fn") {
            if !r.exact
                return "unknown"
            return l.fn == r.fn ? "safe" : "mismatch"
        }

        normalize := l.fn
        return normalize(r.literal) == r.literal ? "safe" : "mismatch"
    }

    /**
     * Whether every case label of a switch statement is a string literal already in the case `fn` produces,
     * so that dropping `fn` from the head and turning CaseSense off keeps the switch's meaning.
     */
    static LabelsMatch(switchNode, fn) {
        body := switchNode.GetChildByFieldName("body")
        loop body.NamedChildCount {
            clause := body.GetNamedChild(A_Index - 1)
            if clause.type != "case_clause"
                continue

            for value in clause.GetChildrenByFieldName("value") {
                if value.type != "string_literal"
                    return false
                text := this.LiteralContent(value)
                if fn(text) !== text   ; `fn` is a parameter, so this calls the normalizer
                    return false
            }
        }
        return true
    }

    /**
     * Fixes that unwrap each normalizing call, keeping its argument: `StrLower(x)` -> `x`. Two small edits
     * per call rather than one replacement, so that fixes inside the argument survive.
     */
    static RemoveCalls(calls) {
        fixes := []
        for call in calls {
            arg := this.Subject(call)
            fixes.Push(
                Fix(call.startByte, arg.startByte, ""),     ; `StrLower(`
                Fix(arg.endByte, call.endByte, "")          ; `)`
            )   
        }
        return fixes
    }

    /** Whether a switch's CaseSense argument turns case sensitivity off ("Off", "Locale", false, 0) */
    static IsCaseInsensitiveArg(node) {
        switch node.type {
            case "string_literal":  return this.LiteralContent(node) ~= "i)^(off|locale)$"
            case "boolean_literal": return node.text = "false"
            case "integer_literal": return node.text == "0"
            default:                return false
        }
    }

    /**
     * Whether `call` returns its first argument's text with case untouched, so a normalization inside it
     * can be hoisted out. `Trim` and friends only qualify without OmitChars, which may be case-sensitive.
     */
    static IsCasePreserving(call) {
        name := this.CalleeName(call)
        if name = "SubStr"
            return !!this.Subject(call)
        if name ~= "i)^(Trim|LTrim|RTrim)$"
            return call.GetChildByFieldName("arguments").NamedChildCount == 1 && !!this.Subject(call)
        return false
    }

    /** The name of the function `call` calls, or an empty string if it isn't called by name */
    static CalleeName(call) {
        fn := call.GetChildByFieldName("function")
        return fn.type == "identifier" ? fn.text : ""
    }

    /** The first argument of `call` (the string being operated on), or 0 if there isn't one */
    static Subject(call) {
        args := call.GetChildByFieldName("arguments")
        if args.IsNull || args.NamedChildCount == 0
            return 0
        first := args.GetNamedChild(0)
        return first.type == "empty_arg" ? 0 : first
    }

    /** The text between a string literal's quotes */
    static LiteralContent(node) => SubStr(node.text, 2, -1)

    static CaseInsensitiveMap(pairs*) {
        m := Map()
        m.CaseSense := false
        m.Set(pairs*)
        return m
    }
}
