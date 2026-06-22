#Requires AutoHotkey v2.1-alpha.30

/**
 * Style lint to disallow call statements and suggest standard Call()
 */
class NoCallStatements {
    static meta => {
        id:          "no-call-statements",
        title:       "No Call Statements",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: false,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Language.htm#function-call-statements",
            "https://www.autohotkey.com/docs/alpha/Concepts.htm#functions"
        ]
    }

    __New(linter) {
        linter.OnEnter("call_statement", (linter, node) {
            fn := Trim(node.GetChildByFieldName("function").Text)
            argsNode := node.GetChildByFieldName("arguments")
            args := argsNode.IsNull ? "" : Trim(argsNode.Text)
            
            msg := Format("Use standard calls instead of call statements: ``{1}({2})``", fn, args)

            linter.Report(NoCallStatements.meta, node, msg)
        })
    }
}