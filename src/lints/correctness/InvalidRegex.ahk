#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "../../lib/Util" { GetArg, FlattenNode }
#Import "../../lib/StringLiteral" { StringValue }

/**
 * Reports regular expressions that don't compile.
 *
 * Only strings that are certainly used as a pattern are checked: the pattern argument of `RegExMatch`
 * and `RegExReplace`, and the right side of `~=`. A variable used there is followed back to the strings
 * assigned to it. Anything that isn't known in full (a parameter, a call, a string built up with `.=`)
 * is left alone, since a fragment of a pattern needn't compile by itself.
 */
class InvalidRegex {
    static meta => {
        id:          "invalid-regex",
        title:       "Invalid Regex",
        category:    "correctness",
        tags:        ["regex"],
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/misc/RegEx-QuickRef.htm",
            "https://www.autohotkey.com/docs/v2/lib/RegExMatch.htm"
        ]
    }

    ; The expressions used as patterns. Checked once the file's scopes are complete
    patterns := []

    __New(linter) {
        linter.scopes.OnComplete(this.CheckPatterns.Bind(this))

        linter.OnEnter(["function_call", "call_statement"], this.SeeCall.Bind(this))
        linter.OnEnter("regex_match_operation", this.SeeMatch.Bind(this))
    }

    /** `RegExMatch(haystack, pattern)`, `RegExReplace(haystack, pattern)` */
    SeeCall(_, node) {
        fn := node.GetChildByFieldName("function")
        if fn.type != "identifier" || !(fn.text ~= "i)^(RegExMatch|RegExReplace)$")
            return

        pattern := GetArg(node, 1) ?? 0
        if pattern && pattern.type != "empty_arg"
            this.patterns.Push(pattern)
    }

    /** `haystack ~= pattern` */
    SeeMatch(_, node) {
        this.patterns.Push(node.GetChildByFieldName("right"))
    }

    CheckPatterns(linter, scopes) {
        checked := Map()   ; start byte of each string checked, as several patterns may share a variable

        for pattern in this.patterns {
            for candidate in InvalidRegex.Candidates(scopes, pattern) {
                if checked.Has(candidate.node.StartByte)
                    continue
                checked[candidate.node.StartByte] := true

                if !(problem := InvalidRegex.CompileError(candidate.value))
                    continue

                message := "This regular expression doesn't compile: " problem
                if candidate.node.StartByte < pattern.StartByte || candidate.node.EndByte > pattern.EndByte
                    message .= Format(". It is used as a pattern on line {1}", pattern.StartPoint.row + 1)
                linter.Report(InvalidRegex.meta, candidate.node, message)
            }
        }
    }

    /**
     * The strings that `node`, an expression used as a pattern, may evaluate to.
     *
     * @param {ScopeTracker} scopes the file's scopes
     * @param {Node} node the expression
     * @returns {Array<{node: Node, value: String}>} each string and the expression that produces it.
     *          Empty if the expression isn't known in full.
     */
    static Candidates(scopes, node) {
        node := FlattenNode(node)
        switch node.type {
            case "ternary_expression":
                ; Expect both branches to be patterns, check them both
                candidates := this.Candidates(scopes, node.GetChildByFieldName("true_branch"))
                candidates.Push(this.Candidates(scopes, node.GetChildByFieldName("false_branch"))*)
                return candidates

            case "identifier":
                ; All or nothing: an assignment we can't evaluate may build on the ones we can
                candidates := []
                for write in this.WritesTo(scopes, node) {
                    if !(folded := this.Fold(scopes, write.value))
                        return []
                    candidates.Push({ node: write.value, value: folded.value })
                }
                return candidates

            default:
                folded := this.Fold(scopes, node)
                return folded ? [{ node: node, value: folded.value }] : []
        }
    }

    /**
     * Evaluate a constant string expression.
     *
     * @param {Map} seen the assignments being evaluated, to stop at variables defined by each other
     * @returns {Object | String} `{value}`, or an empty string if `node` isn't a constant string
     */
    static Fold(scopes, node, seen := Map()) {
        if node.IsNull || node.HasError
            return ""

        switch node.type {
            case "string_literal", "multiline_string_literal":
                return StringValue(node)

            case "parenthesized_expression":
                inner := FlattenNode(node)
                return inner.Equals(node) ? "" : this.Fold(scopes, inner, seen)

            case "implicit_concat_operation", "explicit_concat_operation":
                left := this.Fold(scopes, node.GetChildByFieldName("left"), seen)
                right := left && this.Fold(scopes, node.GetChildByFieldName("right"), seen)
                return right ? { value: left.value . right.value } : ""

            case "assignment_operation":
                ; `a := (b := "x")` assigns "x" to both
                if Trim(node.GetChildByFieldName("operator").text, " `t`r`n") == ":="
                    return this.Fold(scopes, node.GetChildByFieldName("right"), seen)

            case "identifier":
                writes := this.WritesTo(scopes, node)
                if writes.Length != 1 || seen.Has(key := writes[1].value.StartByte)
                    return ""
                seen[key] := true
                folded := this.Fold(scopes, writes[1].value, seen)
                seen.Delete(key)
                return folded
        }
        return ""
    }

    /**
     * Every assignment to the variable `identifier` refers to, if all of them are known.
     *
     * @returns {Array<{node: Node, value: Node}>} empty if the variable can get a value in some way other
     *          than a plain `:=` in this file: it is a parameter, a loop variable, passed by reference,
     *          appended to, or possibly assigned through a dynamic `%name%` reference
     */
    static WritesTo(scopes, identifier) {
        name := identifier.text
        owner := scopes.ScopeOf(identifier).OwnerOf(name)
        if owner.hasDynamicRefs
            return []

        variable := owner.variables.Get(name, "")
        if !variable || !(variable.kind ~= "^(global|local|static)$")
            return []
        return variable.writes.Any(write => !write.value) ? [] : variable.writes
    }

    /**
     * Compile `pattern` with the engine the script will use.
     *
     * @returns {String} what is wrong with it, or an empty string if it compiles
     */
    static CompileError(pattern) {
        ; A callout calls a function by name, and here that would be one of the linter's own
        if InStr(pattern, "(?C")
            return ""

        try RegExMatch("", pattern)
        catch Error as e {
            if RegExMatch(e.Message, "^Compile error \d+ at offset (?<offset>\d+): (?<problem>.*)$", &err)
                return Format("{1} (at offset {2})", err.problem, err.offset)
        }
        return ""
    }
}
