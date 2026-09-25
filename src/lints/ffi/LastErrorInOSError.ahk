#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class LastErrorInOSError {
    static meta => {
        id:          "lasterror-in-oserror",
        title:       "Passed LastError to OSError",
        category:    "ffi",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/Error.htm#OSError"
        ]
    }

    __New(linter) {
        linter.OnEnter("function_call", (linter, node) {
            fn := node.GetChildByFieldName("function")
            if fn.text != "OSError"
                return

            argSeq := node.GetChildByFieldName("arguments")
            if argSeq.IsNull
                return
            
            if argSeq.NamedChildCount == 1 && argSeq.GetNamedCHild(0).text = "A_LastError" {
                linter.Report(LastErrorInOSError.meta, node,
                    "Passing A_LastError to OSError is redundant.", Fix.To(node, "OSError()"))
            }
        })
    }
}