#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }
#Import "../../lib/Util" { IsComment }

/**
 * Flags a `Has` check that picks between an index access and a default, like
 * `m.Has(k) ? m[k] : d`, which is `m.Get(k, d)` in one call.
 */
class UseGetDefault {
    static meta => {
        id:          "use-get-default",
        title:       "Has Check Before Index Access",
        category:    "complexity",
        tags:        [],
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",  ; Get evaluates the default eagerly; the receiver's type is unknown
        recommended: true,
        precision:   "medium",
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/Map.htm#Get",
            "https://www.autohotkey.com/docs/v2/lib/Map.htm#Has",
            "https://www.autohotkey.com/docs/v2/lib/Array.htm#Get"
        ]
    }

    __New(linter) {
        linter.OnEnter("ternary_expression", this.CheckTernary.Bind(this))
        linter.OnEnter("if_statement", this.CheckIf.Bind(this))
    }

    /** `m.Has(k) ? m[k] : d` */
    CheckTernary(linter, node) {
        if !(has := UseGetDefault.MatchHas(node.GetChildByFieldName("condition")))
            return

        hit := node.GetChildByFieldName(has.negated ? "false_branch" : "true_branch")
        miss := node.GetChildByFieldName(has.negated ? "true_branch" : "false_branch")
        if !UseGetDefault.IsIndexOf(hit, has.obj, has.key)
            return

        replacement := UseGetDefault.GetCall(has, miss)
        message := Format("Use ``{1}`` instead of checking ``Has`` first.", replacement)
        linter.Report(UseGetDefault.meta, node, message, [Fix.To(node, replacement)])
    }

    /** `if m.Has(k) { v := m[k] } else { v := d }` */
    CheckIf(linter, node) {
        elseBlock := node.GetChildByFieldName("else_block")
        if elseBlock.IsNull
            return
        if !(has := UseGetDefault.MatchHas(node.GetChildByFieldName("condition")))
            return

        ifBody := UseGetDefault.SingleAssignment(node.GetChildByFieldName("body"))
        elseBody := UseGetDefault.SingleAssignment(elseBlock.GetChildByFieldName("body"))
        if !ifBody || !elseBody
            return

        target := Trim(ifBody.GetChildByFieldName("left").Text, " `t`r`n")
        if target != Trim(elseBody.GetChildByFieldName("left").Text, " `t`r`n")
            return

        hit := has.negated ? elseBody : ifBody
        miss := has.negated ? ifBody : elseBody
        if !UseGetDefault.IsIndexOf(hit.GetChildByFieldName("right"), has.obj, has.key)
            return

        replacement := target " := " UseGetDefault.GetCall(has, miss.GetChildByFieldName("right"))
        message := Format("Use ``{1}`` instead of checking ``Has`` first.", replacement)
        linter.Report(UseGetDefault.meta, node, message, [Fix.To(node, replacement)])
    }

    /** The text of the call `obj.Get(key, default)` */
    static GetCall(has, fallback) =>
        Format("{1}.Get({2}, {3})", has.obj, has.key, UseGetDefault.Clean(fallback))

    /**
     * Match `obj.Has(key)` or `!obj.Has(key)`, possibly parenthesized.
     * @returns {Object | String} `{obj, key, negated}` with `obj` and `key` as text, or "" if `cond` isn't a `Has` check
     */
    static MatchHas(cond) {
        cond := UseGetDefault.Unwrap(cond)
        negated := false
        if cond.Type == "prefix_operation" && cond.GetChildByFieldName("operator").Type == "!" {
            negated := true
            cond := UseGetDefault.Unwrap(cond.GetChildByFieldName("operand"))
        }

        if cond.Type != "function_call"
            return ""
        callee := cond.GetChildByFieldName("function")
        if callee.Type != "member_access"
            return ""
        member := callee.GetChildByFieldName("member")
        if !(member.Type == "identifier" && member.Text = "Has")
            return ""
        if !(key := UseGetDefault.SingleArg(cond))
            return ""

        return {
            obj: UseGetDefault.Clean(callee.GetChildByFieldName("object")),
            key: UseGetDefault.Clean(key),
            negated: negated
        }
    }

    /** Whether `node` is `obj[key]`, comparing the text of each */
    static IsIndexOf(node, obj, key) {
        node := UseGetDefault.Unwrap(node)
        if node.Type != "index_access" || !(arg := UseGetDefault.SingleArg(node))
            return false
        return UseGetDefault.Clean(node.GetChildByFieldName("object")) == obj
            && UseGetDefault.Clean(arg) == key
    }

    /** The only argument of a call or index access, or "" if it doesn't have exactly one plain argument */
    static SingleArg(node) {
        args := node.GetChildByFieldName("arguments")
        if args.IsNull || args.NamedChildCount != 1
            return ""
        arg := args.GetNamedChild(0)
        return arg.Type ~= "^(empty_arg|array_expansion_operation)$" ? "" : arg
    }

    /**
     * The `:=` assignment that is the only statement in an `if` or `else` body, ignoring comments.
     * @returns {Node | String} the `assignment_operation`, or "" if the body is anything else
     */
    static SingleAssignment(body) {
        if body.Type == "block" {
            statements := body.GetNamedChildren().Filter(child => !IsComment(child))
            if statements.Length != 1
                return ""
            body := statements[1]
        }

        body := UseGetDefault.Unwrap(body)
        if body.Type != "assignment_operation" || body.GetChildByFieldName("operator").Text != ":="
            return ""
        return body
    }

    /**
     * Drill through parentheses and single-expression sequences. Unlike `FlattenNode`, this
     * stops at anything else, so `!x` stays a `prefix_operation`.
     */
    static Unwrap(node) {
        while node.Type ~= "^(parenthesized_expression|expression_sequence)$" && node.NamedChildCount == 1
            node := node.GetNamedChild(0)
        return node
    }

    static Clean(node) => Trim(node.Text, " `t`r`n")
}
