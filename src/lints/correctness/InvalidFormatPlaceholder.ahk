#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util" { StrJoin }
#Import "../../lib/Format" { CollectPlaceholders }

class InvalidFormatPlaceholder {
    static meta => {
        id:          "invalid-format-placeholder",
        title:       "Invalid Format Placeholder",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "error",
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

        args := node.GetChildByFieldName("arguments")
        if args.IsNull
            return

        fmtString := args.GetNamedChild(0)
        if fmtString.IsNull || fmtString.type != "string_literal"
            return

        invalid := CollectPlaceholders(fmtString.text).Filter(p => !p.IsValid)

        if invalid.length > 0 {
            errors := StrJoin(", ", invalid.Map(p => Format("'{1}' ({2})", String(p), p.error))*)
            message := Format("{1} format placeholder(s) are invalid: {2}", invalid.length, errors)

            linter.Report(InvalidFormatPlaceholder.meta, fmtString, message)
        }
    }
}
