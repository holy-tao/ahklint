#Requires AutoHotkey v2.1-alpha.30

/**
 * A file should declare exactly one requires directive
 */
class OneRequires {
    static meta => {
        id:          "one-requires",
        title:       "Declare One Requires Directive",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/_Requires.htm",
            "https://www.autohotkey.com/docs/v2/Program.htm#launcher"
        ]
    }

    /**
     * Constructor
     * @param {Linter} linter the linter 
     * @returns {unset?} 
     */
    __New(linter) {
        this.count := 0
        linter.OnEnter("requires_directive", (visitor, node) {
            if this.count >= 1 {
                visitor.Report(OneRequires.meta, node, "Multile #Requires directives found.")
            }

            this.count++
        })
        linter.OnExit("source_file", (visitor, node) {
            if this.count == 0
                visitor.Report(OneRequires.meta, node, "Missing #Requires directive.")
        })
    }
}