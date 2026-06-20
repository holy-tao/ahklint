#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode }

class NoCdecl {
    static meta => {
        id:          "no-cdecl",
        title:       "Always Omit CDecl",
        category:    "ffi",
        versions:    ">=2.1-alpha.3",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/DllCall.htm#cdecl"
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
        static message := "Specifying Cdecl has no effect even on 32-bit builds, and can always be omitted."
        if node.GetChildByFieldName("function").Text != "DllCall" {
            return
        }

        argSeq := node.GetChildByFieldName("arguments")
        if argSeq.IsNull || (argSeq.NamedChildCount < 1) {
            return
        }

        typeArg := FlattenNode(argSeq.GetNamedChild(argSeq.NamedChildCount - 1))
        if typeArg.IsNull || typeArg.Type != "string_literal" {
            ; Struct class or perhaps no type arg at all
            return
        }

        if InStr(typeArg.Text, "cdecl") {
            linter.Report(NoCdecl.meta, typeArg, message)
        }
    }
}