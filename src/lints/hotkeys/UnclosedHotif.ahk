#Requires AutoHotkey v2.1-alpha.30

/**
 * Warn if a script contains an unclosed #HotIf directive - it would bleed into any scripts
 * that #Include it. Less relevant for v2.1, modules get their own auto-execute sections.
 */
class UnclosedHotif {
    static meta => {
        id:          "unclosed-hotif",
        title:       "Unclosed HotIf Directive",
        category:    "hotkeys",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/_HotIf.htm",
        ]
    }

    /** The last #HotIf directive we saw with a condition, empty string if none */
    _lastNode := ""

    __New(linter) {
        linter.OnEnter("hotif_directive", this.SeeHotIfDirective.Bind(this))
        linter.OnExit("source_file", this.Report.Bind(this))
    }

    SeeHotIfDirective(_linter, node) {
        if node.GetChildByFieldName("expression").IsNull {
            this._lastNode := ""
        } else {
            this._lastNode := node
        }
    }

    Report(linter, _node) {
        if this._lastNode
            linter.Report(UnclosedHotif.meta, this._lastNode, "Unclosed #HotIf directive.")
    }
}