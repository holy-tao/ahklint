#Requires AutoHotkey v2.1-alpha.30

class SyntaxError {
    static meta => {
        id:          "syntax-error",
        title:       "Syntax Error",
        category:    "correctness",
        tags:        [],
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/alpha/Language.htm"]
    }

    __New(linter) {
        ; TODO might be faster to run a query for ERROR and MISSING nodes once on entering or exiting `source_file`
        ; instead of running a check for every node in the tree?
        linter.OnEnter("*", this.CheckNode.Bind(this))
    }

    CheckNode(linter, node) {
        if node.isError {
            linter.Report(SyntaxError.meta, node, "Syntax error")
        } else if node.isMissing {
            linter.Report(SyntaxError.meta, node, "Syntax error: expected a(n) '" node.type "'")
        }
    }
}
