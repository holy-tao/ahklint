#Requires AutoHotkey v2.1-alpha.30

/**
 * Prefer `[1, 2, 3]` over `Array(1, 2, 3)`
 */
class PreferArrayBracketForm {
    static meta => {
        id:          "prefer-array-bracket-form",
        title:       "Prefer Array Bracket Forms",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/Array.htm",
        ]
    }

    __New(linter) {
        linter.OnEnter("function_call", (linter, node) {
            callee := node.GetChildByFieldName("function")
            if !(callee.type == "identifier" && callee.text = "array") {
                return
            }

            argStr := ""
            args := node.GetChildByFieldName("arguments")
            if !args.IsNull {
                fullArgStr := args.text ; May contain newlines
                argStr := InStr(fullArgStr, "`n")
                    ? StrSplit(fullArgStr, "`n", " `r`n`t")[1] " ..."
                    : fullArgStr
            }

            linter.Report(PreferArrayBracketForm.meta, node,
                Format("Prefer the bracket list form: ``[{1}]``", argStr))
        })
    }
}