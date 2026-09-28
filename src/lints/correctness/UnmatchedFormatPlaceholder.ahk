#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util" { StrJoin }

/**
 * Check for unmatched format placeholders or format arguments with no corresponding placeholders.
 *
 * Note, does *not* check that placeholders are valid, that's a slightly different correctness concern
 * (it will cause a runtime error instead of undesired behavior) and is the domain of another lint.
 */
class UnmatchedFormatPlaceholder {
    static meta => {
        id:          "unmatched-format-placeholder",
        title:       "Unmatched Format Placeholder or Argument",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/v2/lib/Format.htm"]
    }

    __New(linter) {
        linter.OnEnter(["function_call", "call_statement"], this.CheckFunctionCall.Bind(this))
    }

    CheckFunctionCall(linter, node) {
        if node.GetChildByFieldName("function").Text != "Format"
            return

        args := node.GetChildByFieldName("arguments").GetNamedChildren()
        if args[1].type != "string_literal"
            return ; not a string literal, can't reliably analyze it

        fmtString := args.RemoveAt(1) ; args now only has the format placeholder matches
        placeholders := UnmatchedFormatPlaceholder.CollectPlaceholders(fmtString.text)

        ; Check for unmatched placeholders
        unmatched := placeholders.Filter(p => p.index > args.length).Map(p => p.text)
        if unmatched.length > 0 {
            message := Format("{1} unmatched placeholder(s): {2}", unmatched.length, StrJoin(", ", unmatched*))
            linter.Report(UnmatchedFormatPlaceholder.meta, fmtString, message)
        }

        ; Check for arguments unused by any placeholder
        usedIndices := placeholders.Map(p => p.index)
        for arg in args {
            idx := A_Index
            if usedIndices.Any(i => i == idx)
                continue

            linter.Report(UnmatchedFormatPlaceholder.meta, arg,
                "Format argument " idx " has no matching placeholder")
        }
    }

    /**
     * Collects all format placeholders in a Format string, returning an array of `{ text, index }` objects
     * for each placeholder. The placeholders appear in the array in the order in which they appear in the
     * string, which isn't necessarily the order of the arguments they consume; you have `{1}` as the third
     * item.
     *
     * @param {String} fmtString the first argument to Format
     * @returns {Array<{text, index}>} 
     */
    static CollectPlaceholders(fmtString) {
        ; Per docs: "Omit the index to use the next input value in the sequence
        ; (even if it has been used earlier in the string)"
        lastIndex := 0, placeholders := []

        match := "", pos := 1
        while RegExMatch(fmtString, "{(?<idx>\d+)?:?[^{}]*}", &match, pos) {
            placeholders.Push({
                text: match[0],
                index: IsInteger(match.idx)
                    ? lastIndex := Integer(match.idx)
                    : ++lastIndex 
            })

            pos := match.Pos + match.Len
        }

        return placeholders
    }
}