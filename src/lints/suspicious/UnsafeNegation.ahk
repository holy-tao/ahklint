#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class UnsafeNegation {
    static meta => {
        id:          "unsafe-negation",
        title:       "Unsafe Negation",
        category:    "suspicious",
        tags:        [],
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: true,
        references:  [],
        options: {
            enforceForOrderingRelations: {
                type:        "boolean",
                default:     false,
                description: "When true, also enforce this rule for <, >, <=, and >=."
            }
        }
    }

    __New(linter) {
        enforceOrdering := linter.Options(UnsafeNegation.meta).enforceForOrderingRelations
        linter.OnEnter("type_check_operation", this.Check.Bind(this))
        if enforceOrdering
            linter.OnEnter("relational_operation", this.Check.Bind(this))
    }

    Check(linter, node) {
        left := node.GetChildByFieldName("left")
        if left.type != "prefix_operation"
            return

        if InStr(left.text, "!") != 1
            return

        msg := Format("This negation makes the left-hand side an Integer. Did you mean ``!({1})``?", SubStr(node.text, 2))
        linter.Report(UnsafeNegation.meta, node, msg, [
            Fix(left.startByte, left.startByte + 1, "!("),
            Fix.Insert(node.GetChildByFieldName("right").endByte, ")")
        ])
    }
}
