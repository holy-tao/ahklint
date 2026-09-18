#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode }

; TODO config opportunity - reasonable to allow "ptr" to keep the obj.ptr resolution logic

/**
 * Prefer using struct or type classes over bare strings in `DllCall` and `ComCall` where possible.
 */
class UseTypeClasses {
    static meta => {
        id:          "use-type-classes",
        title:       "Use Type Classes",
        category:    "ffi",
        versions:    ">=2.1-alpha.23",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/DllCall.htm#types",
            "https://www.autohotkey.com/docs/alpha/lib/CallbackCreate.htm#Parameters"
        ]
    }

    /**
     * Map of string DllCall types to their equivalent replacements in v2.1, when
     * such equivalent replacements exist. For */P suffixes, append `.Ptr` to the
     * v2.1 class
     * @type {Map<String, String>}
     */
    DllCallTypes := Map()

    __New(linter) {
        this.DllCallTypes.CaseSense := "off"
        ; NOTE: astr / wstr / str omitted since they have no v2.1 equivalent now
        ;       hresult and void similarly have special semantics and aren't included
        this.DllCallTypes.Set(
            "Int64",    "Int64",
            "Int",      "Int32",
            "UInt",     "UInt32",
            "Short",    "Int16",
            "UShort",   "UInt16",
            "Char",     "Int8",
            "UChar",    "UInt8",
            "Float",    "Float32",
            "Double",   "Float64",
            "Ptr",      "IntPtr"
        )

        linter.OnEnter("function_call", this.Evaluate.Bind(this))
        linter.OnEnter("call_statement", this.Evaluate.Bind(this))
    }

    Evaluate(linter, node) {
        argSeq := node.GetChildByFieldName("arguments")
        if argSeq.IsNull || (argSeq.NamedChildCount < 1) {
            return
        }

        switch node.GetChildByFieldName("function").Text {
            case "DllCall":
                ; fn name is at index 0; type args are at 1, 3, 5, ...
                this._EvalTypeArgs(linter, argSeq, 1)
            case "ComCall":
                ; vtable index is 0, interface is 1; type args are at 2, 4, 6, ...
                this._EvalTypeArgs(linter, argSeq, 2)
        }
    }

    /**
     * Evaluate type args in `argSeq` starting at `startIdx` (0-based), every 2
     * positions. Filters out extra nodes (line comments etc.) first - tree-sitter
     * includes them as named children inside arg_sequence, which would corrupt the
     * stride if counted.
     */
    _EvalTypeArgs(linter, argSeq, startIdx) {
        args := []
        loop argSeq.NamedChildCount {
            child := argSeq.GetNamedChild(A_Index - 1)
            if !child.IsExtra
                args.Push(child)
        }
        i := startIdx + 1   ; args is 1-indexed in AHK
        while i <= args.Length {
            this.EvaluateArg(linter, args[i])
            i += 2
        }
    }

    /**
     * Report if `argNode` violates this rule
     */
    EvaluateArg(linter, argNode) {
        argNode := FlattenNode(argNode)
        if argNode.Type != "string_literal" {
            return
        }

        nodeText := SubStr(argNode.Text, 2, -1)         ; Unquote the string literal
        nodeText := Trim(StrReplace(nodeText, "cdecl")) ; Strip cdecl in case this is a return type

        last := SubStr(nodeText, -1, 1)
        isPtr := last == "*" || last == "p"
        
        if isPtr {
            ; If a pointer-to-primitive type ("ptr*", "uintp"), strip the last character
            nodeText := Trim(SubStr(nodeText, 1, -1))
        }

        if this.DllCallTypes.Has(nodeText) {
            msg := Format("Use v2.1 type or struct classes: ``{1}{2}``", 
                this.DllCallTypes[nodeText], isPtr ? ".Ptr" : "")

            if nodeText = "ptr"
                msg .= ". If this is a pointer to a struct, use ``StructClass.Ptr``."
            
            linter.Report(UseTypeClasses.meta, argNode, msg)
        }
    }
}
