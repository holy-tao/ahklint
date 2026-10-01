#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

KEYWORDS :=  [
    "if", "else", "while", "for", "loop", "until", "return", "break", "continue", "goto",
    "try", "catch", "finally", "throw", "switch", "case", "default", "class", "extends",
    "get", "set", "as", "is", "in", "unset", "and", "or", "not", "export", "struct", "global",
    "scope_identifier", "boolean_literal"
]

class KeywordCapitalization {
    static meta => {
        id:          "keyword-capitalization",
        title:       "Keyword Capitalization",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: true,
        references:  []
    }

    __New(linter) {
        linter.OnEnter(KEYWORDS, (linter, node) {
            if !IsLower(text := node.text) {
                linter.Report(
                    KeywordCapitalization.meta,
                    node,
                    "Keywords should be lowercase",
                    Fix.To(node, StrLower(text))
                )
            }
        })
    }
}
