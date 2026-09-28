#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }
#Import "../../lib/StringCase" {
    CollectNormalizations, ClassifyCase, CaseEquivalence, LiteralHasCase, IsCaseInsensitiveArg, CalleeName, Subject
}

/**
 * Warn for string equality comparisons and switch statements that normalize the case of a string in order
 * to do a case-insensitive comparison. AHK has built-in operators for this that will reduce code complexity
 * and marginally improve performance.
 *
 * Finding a normalization and fixing it are kept separate: `CollectNormalizations` returns the normalizing
 * call nodes themselves, however deeply they are wrapped, and each one is fixed by the same two patches
 * (remove `StrLower(` and the closing `)`) regardless of what surrounds it.
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

    __New(linter) {
        linter.OnEnter(["equality_operation", "inequality_operation"], this.CheckComparison.Bind(this))
        linter.OnEnter("switch_statement", this.CheckSwitch.Bind(this))
    }

    CheckComparison(linter, node) {
        left := node.GetChildByFieldName("left")
        right := node.GetChildByFieldName("right")

        calls := CollectNormalizations(left)
        CollectNormalizations(right, calls)
        if !calls.Length
            return

        fnName := CalleeName(calls[1])
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

        switch CaseEquivalence(left, right) {
            case "safe":
                fixes := CaseNormalization.RemoveCalls(calls)
                fixes.Push(Fix.To(op, insensitiveOp))
                linter.Report(CaseNormalization.meta, node, message, fixes)

            ; e.g. `StrLower(a) == "Bob"` - the comparison is constant, which is a bug rather than a
            ; simplification, and suggesting `=` would silently change what the code does. Reported by
            ; constant-comparison instead.
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

        calls := CollectNormalizations(head)
        if !calls.Length
            return

        fnName := CalleeName(calls[1])
        caseSense := node.GetChildByFieldName("case_sense")

        if !caseSense.IsNull && IsCaseInsensitiveArg(caseSense) {
            message := Format("Calling ``{1}`` is unnecessary here; the switch is already case-insensitive", fnName)
            linter.Report(CaseNormalization.meta, head, message, CaseNormalization.RemoveCalls(calls))
            return
        }

        message := Format("Set the switch's CaseSense to {1} instead of calling ``{2}``", '"Off"', fnName)

        side := ClassifyCase(head)
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
                if value.type != "string_literal" || !LiteralHasCase(value.text, fn)
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
            arg := Subject(call)
            fixes.Push(Fix(call.startByte, arg.startByte, ""))   ; `StrLower(`
            fixes.Push(Fix(arg.endByte, call.endByte, ""))       ; `)`
        }
        return fixes
    }
}
