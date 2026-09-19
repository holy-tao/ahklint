#Requires AutoHotkey v2.1-alpha.30

class EmptySwitchCase {
    static meta => {
        id:          "empty-switch-case",
        title:       "Empty Switch Case",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/v2/lib/Switch.htm"]
    }

    __New(linter) {
        linter.OnEnter(["case_clause", "default_clause"], (linter, node) {
            body := node.GetChildByFieldName("body")
            if body.IsNull {
                linter.Report(EmptySwitchCase.meta, node, 
                    "Empty switch case. AHK switch cases don't fall through; a match on this case will no-op.")
            }
        })
    }
}