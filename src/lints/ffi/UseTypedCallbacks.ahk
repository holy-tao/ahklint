#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode }

/**
 * Prefer typed CallbackCreates, in v2.1-alpha.24+
 */
class UseTypedCallbacks {
    static meta => {
        id:          "use-typed-callbacks",
        title:       "Use Typed Callbacks",
        category:    "ffi",
        versions:    ">=2.1-alpha.24",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/CallbackCreate.htm"
        ]
    }

    __New(linter) {
        linter.OnEnter("function_call", this.Evaluate.Bind(this))
        linter.OnEnter("call_statement", this.Evaluate.Bind(this))
    }

    /**
     * Evaulate a function call or call statement to see if the rule should apply
     * @param {Linter} linter the linter 
     * @param {Node} node the tree-sitter node to evaluate
     */
    Evaluate(linter, node) {
        if node.GetChildByFieldName("function").Text != "CallbackCreate" {
            return
        }

        argSeq := node.GetChildByFieldName("arguments")
        if argSeq.IsNull || (argSeq.NamedChildCount < 3) {
            linter.Report(UseTypedCallbacks.meta, node, "CallbackCreate calls must always include a ParamSpec")
            return
        }

        optsNode := FlattenNode(argSeq.GetNamedChild(1))
        if (optsNode.Type == "string_literal") && InStr(optsNode.Text, "&") {
            ; Definitely a by-address function, no typing
            return
        }

        ; TODO improve this, maybe try evaluating expressions or something?
        ; but int literals are the most common of these because that was the
        ; only typing available in v2.1
        paramSpecType := FlattenNode(argSeq.GetNamedChild(2)).Type
        if paramSpecType = "integer_literal" {
            linter.Report(UseTypedCallbacks.meta, node, "Use typed CallbackCreate ParamSpecs")
        }
    }
}