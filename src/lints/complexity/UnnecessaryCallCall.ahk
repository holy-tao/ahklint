#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class UnnecessaryCallCall {
    static meta => {
        id:          "unnecessary-call-call",
        title:       "Unnecessary Call to Call",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
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
                argsNode := node.GetChildByFieldName("arguments")
                patch := Fix.To(node, Format("{1}({2})", 
                    callee.GetChildByFieldName("object").text,
                    argsNode.IsNull ? "" : argsNode.text))

                message := Format("Unnecessary call to ``Call`` - ``()`` invokes it implicitly.")
                linter.Report(UnnecessaryCallCall.meta, node, message, patch)
            }
        })
    }
}