#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class DirectToStringCall {
        static meta => {
        id:          "direct-tostring-call",
        title:       "Direct Call to ToString",
        category:    "suspicious",
        tags:        [],
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/v2/lib/String.htm"]
    }

    __New(linter) {
        linter.OnEnter("function_call", this.Check.Bind(this))
    }

    Check(linter, node) {
        ; ToString with arguments is allowed
        if !node.GetChildByFieldName("arguments").IsNull
            return

        ; Not a method call
        fn := node.GetChildByFieldName("function")
        if fn.type != "member_access"
            return

        if fn.GetChildByFieldName("member").text = "ToString" {
            obj := fn.GetChildByFieldName("object")
            linter.Report(DirectToStringCall.meta, node,
                "Use ``String`` instead of calling ``ToString()`` as a method", [
                    Fix.Insert(obj.startByte, "String("), Fix(obj.endByte, node.endByte, ")")
                ])
        }
    }
}
