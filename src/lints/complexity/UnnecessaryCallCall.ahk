#Requires AutoHotkey v2.1-alpha.30

class UnnecessaryCallCall {
    static meta => {
        id:          "unnecessary-call-call",
        title:       "Unnecessary Call to Call",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Language.htm#function-calls",
        ]
    }

    __New(linter) {
        linter.OnEnter("function_call", (linter, node) {
            callee := node.GetChildByFieldName("function")
            if callee.type != "member_access"
                return

            member := callee.GetChildByFieldName("member")
            if Trim(member.text) = "call" {
                message := Format("Unnecessary call to ``Call`` - ``()`` invokes it implicitly.")
                linter.Report(UnnecessaryCallCall.meta, node, message)
            }
        })
    }
}