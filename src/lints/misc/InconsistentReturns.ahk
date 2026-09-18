#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import treesitter { Node }
#Import "collections/Set" { Set }
#Import "../../lib/Util" { FirstNamedChildOfType }

/**
 * Errors if a function sometimes returns a value but sometimes doesn't
 */
class InconsistentReturns {
    static meta => {
        id:          "inconsistent-returns",
        title:       "Inconsistent Returns",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/Return.htm",
            "https://www.autohotkey.com/docs/alpha/v2.1-changes.htm#blank-unset"
        ]
    }

    ; Node types that start a new return scope
    static fnTypes := ["function_declaration", "method_declaration", "function_expression", "getter", "setter"]

    ; Nodes whose bodies are a separate return scope; flow analysis never descends into them
    static nestedScopeTypes := Set(
        "function_declaration",
        "method_declaration",
        "function_expression",
        "fat_arrow_function",
        "class_declaration"
    )

    ; Built-ins that never return control to the caller. Everything else is assumed to return
    static noReturnFns := Set("exitapp", "exit")

    ; Array of { returns: [{ node, hasValue }], hasGoto } objects
    frames := []

    __New(linter) {
        linter.OnEnter(InconsistentReturns.fnTypes, this.EnterFn.Bind(this))
        linter.OnExit(InconsistentReturns.fnTypes, this.ExitFn.Bind(this))

        linter.OnEnter("return_statement", this.SeeReturn.Bind(this))
        linter.OnEnter("goto_statement", this.SeeGoto.Bind(this))
    }

    EnterFn(*) => this.frames.Push({ returns: [], hasGoto: false })

    ExitFn(linter, node) {
        frame := this.frames.Pop()

        ; Setter return values are discarded
        if node.Type == "setter"
            return

        withValue := frame.returns.Filter(ret => ret.hasValue).Length
        if withValue == 0
            return ; never returns a value, so an implicit return is fine

        ; Only look for an implicit return if the end of the body is reachable. Goto makes
        ; reachability unknowable, so skip that check (but still check the explicit returns)
        body := InconsistentReturns.GetBodyBlock(node)
        implicit := !body.IsNull && !frame.hasGoto && InconsistentReturns.CanCompleteNormally(body)

        if withValue == frame.returns.Length && !implicit
            return ; no inconsistencies

        minority := withValue < (frame.returns.Length // 2)
        message := Format("Inconsistent returns. Most returns in this function{1} return a value, but this one {2}.",
            minority ? " don't" : "", minority ? "does" : "doesn't")
        for ret in frame.returns {
            if ret.hasValue == minority
                linter.Report(InconsistentReturns.meta, ret.node, message)
        }

        if implicit {
            closeBrace := body.GetChild(body.ChildCount - 1)
            linter.Report(InconsistentReturns.meta, closeBrace,
                "Function returns a value on some paths but can reach its end without returning one.")
        }
    }

    /**
     * Record a return statement for the current function, if any
     */
    SeeReturn(_, node) {
        ; Don't check the auto-execute section
        if this.frames.Length <= 0
            return

        this.frames[-1].returns.Push({
            node: node,
            hasValue: !node.GetChildByFieldName("value").IsNull
        })
    }

    SeeGoto(*) {
        if this.frames.Length > 0
            this.frames[-1].hasGoto := true
    }

    /**
     * Get the block making up a function's body, or a null node if there isn't one (e.g.
     * fat-arrow functions, which always return a value)
     */
    static GetBodyBlock(fnNode) {
        body := fnNode.Type == "function_expression"
            ? fnNode.GetChildByFieldName("body")
            : FirstNamedChildOfType(fnNode, "function_body")

        if !body.IsNull && body.Type == "function_body"
            body := body.GetNamedChild(0)

        return (!body.IsNull && body.Type == "block") ? body : Node()
    }

    /**
     * Whether control can reach the end of `node` without leaving the function. Errs on the
     * side of "yes" for anything it doesn't understand - calls are assumed to return, and
     * loops other than obviously-infinite ones are assumed to terminate.
     *
     * @param {Node} node a statement node
     * @returns {Boolean} true if execution may continue past `node`
     */
    static CanCompleteNormally(node) {
        switch node.Type {
            case "return_statement", "throw_statement":
                return false

            case "block":
                return this.SequenceCompletes(node.GetNamedChildren())

            case "call_statement", "function_call":
                fn := node.GetChildByFieldName("function")
                return !(fn.Type == "identifier" && this.noReturnFns.Has(StrLower(this.TextOf(fn))))

            case "if_statement":
                elseNode := node.GetChildByFieldName("else_block")
                if elseNode.IsNull
                    return true
                return this.SequenceCompletes(node.GetChildrenByFieldName("body"))
                    || this.SequenceCompletes(elseNode.GetChildrenByFieldName("body"))

            case "switch_statement":
                ; AHK cases don't fall through, and `break` doesn't target a switch
                clauses := node
                    .GetChildByFieldName("body")
                    .GetNamedChildren()
                    .Filter(c => c.Type == "case_clause" || c.Type == "default_clause")

                if !clauses.Any(c => c.Type == "default_clause")
                    return true ; no default, so the value may not match any case

                return clauses.Any(c => this.SequenceCompletes(c.GetChildrenByFieldName("body")))

            case "try_statement":
                return this.TryCompletes(node)

            case "loop_statement", "while_statement":
                return !this.IsInfiniteLoop(node) || this.HasBreakFor(node)

            default:
                ; Loops, expressions, declarations, labels, etc.
                return true
        }
    }

    /**
     * A statement sequence completes normally iff every statement in it does; anything after a
     * non-completing statement is unreachable (goto is handled by the caller)
     */
    static SequenceCompletes(statements) {
        for stmt in statements {
            if !this.CanCompleteNormally(stmt)
                return false
        }
        return true
    }

    /**
     * try / catch / else / finally. All parts of a try statement are `body` fields; the first is
     * the try body itself
     */
    static TryCompletes(node) {
        parts := node.GetChildrenByFieldName("body")
        tryBody := parts.RemoveAt(1)

        catches := [], elseNode := "", finallyNode := ""
        for part in parts {
            switch part.Type {
                case "catch_clause": catches.Push(part)
                case "else_statement": elseNode := part
                case "finally_clause": finallyNode := part
            }
        }

        ; A finally that leaves the function overrides everything else
        if finallyNode && !this.SequenceCompletes(finallyNode.GetChildrenByFieldName("body"))
            return false

        ; A bare `try` with no catch or finally behaves as if it had an empty catch
        if catches.Length == 0 && !finallyNode
            return true

        ; else runs only if the try body completes without throwing
        if this.CanCompleteNormally(tryBody)
            && (!elseNode || this.SequenceCompletes(elseNode.GetChildrenByFieldName("body")))
            return true

        if catches.Any(c => this.SequenceCompletes(c.GetChildrenByFieldName("body")))
            return true
        return false
    }

    /**
     * `Loop` with no count/mode and no `until`, or `while true`
     */
    static IsInfiniteLoop(node) {
        if node.Type == "loop_statement"
            return node.GetChildByFieldName("head").IsNull
                && node.GetChildByFieldName("until_block").IsNull

        cond := node.GetChildByFieldName("condition")
        switch cond.Type {
            case "boolean_literal": return StrLower(this.TextOf(cond)) == "true"
            case "integer_literal": return Integer(this.TextOf(cond)) != 0
            default: return false
        }
    }

    /**
     * Whether any `break` inside `loopNode` exits it
     */
    static HasBreakFor(loopNode) {
        label := ""
        prev := loopNode.PreviousNamedSibling
        while !prev.IsNull && prev.IsExtra
            prev := prev.PreviousNamedSibling
        if !prev.IsNull && prev.Type == "label"
            label := this.TextOf(prev.GetChildByFieldName("name"))

        return loopNode.GetChildrenByFieldName("body")
            .Any(child => this.FindBreak(child, 0, label))
    }

    /**
     * @param {Node} node the node to search
     * @param {Integer} depth how many loops deep inside the target loop `node` is
     * @param {String} label the target loop's label, if any
     */
    static FindBreak(node, depth, label) {
        if this.nestedScopeTypes.Has(node.Type)
            return false

        if node.Type == "break_statement" {
            target := node.GetChildByFieldName("looplabel")
            if target.IsNull
                return depth == 0

            ; `break 2` exits two loops; `break Label` / `break "Label"` exits the labeled one
            text := Trim(this.TextOf(target), "`"'")
            if target.Type == "integer_literal"
                return Integer(text) == depth + 1
            return label != "" && StrLower(text) == StrLower(label)
        }

        if node.Type ~= "^(loop|while|for)_statement$" {
            ; a loop's else/until blocks run outside the loop body
            loop node.ChildCount {
                child := node.GetChild(A_Index - 1)
                inBody := node.GetFieldNameForChild(A_Index - 1) == "body"
                if child.IsNamed && this.FindBreak(child, inBody ? depth + 1 : depth, label)
                    return true
            }
            return false
        }

        return node.GetNamedChildren()
            .Any(child => this.FindBreak(child, depth, label))
    }

    ;@region Node helpers

    /**
     * Node text without surrounding whitespace - the grammar can include leading indentation
     * in a node's span
     */
    static TextOf(node) => Trim(node.Text, " `t`r`n")

    ;@endregion
}
