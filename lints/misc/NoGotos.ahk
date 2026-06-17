#Requires AutoHotkey v2.1-alpha.30

/**
 * Disallow all goto statements
 */
class NoGotos {
    static meta => {
        id:          "no-goto",
        title:       "Disallow Goto",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: false,
        docs:        "https://ahklint.dev/lints/no-goto",
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/Goto.htm"
        ]
    }

    ; Pulled straight from the docs - split out because it's a long string
    static message => "The use of Goto is discouraged. Consider using Else, Blocks, Break, and Continue as substitutes for Goto."

    __New(linter) {
        ; Simple lint - report on every goto statement.
        linter.OnEnter("goto_statement",
            (visitor, node) => visitor.Report(NoGotos.meta, node, NoGotos.message))
    }
}