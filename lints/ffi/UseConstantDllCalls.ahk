#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode }

/**
 * Prefer typed CallbackCreates, in v2.1-alpha.24+
 */
class UseConstantDllCalls {
    static meta => {
        id:          "use-const-dllcalls",
        title:       "Use Constant DllCalls",
        category:    "ffi",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/DllCall.htm#load"
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
        if node.GetChildByFieldName("function").Text != "DllCall" {
            return
        }

        argSeq := node.GetChildByFieldName("arguments")
        if argSeq.IsNull || (argSeq.NamedChildCount < 1) {
            return
        }

        arg1 := FlattenNode(argSeq.GetNamedChild(0))
        if arg1.Type != "string_literal" {
            linter.Report(UseConstantDllCalls.meta, arg1, "Use constant string literals to identify DllCall functions.")
        }
    }
}