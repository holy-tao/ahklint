#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode }

/**
 * Error unconditionally if the script calls SendPlay or tries to send input in SendPlay mode.
 */
class SendPlayDeprecated {
    static meta => {
        id:          "sendplay-deprecated",
        title:       "SendPlay is Deprecated",
        category:    "hotkeys",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/SendMode.htm#Play"
        ]
    }

    static MESSAGE => "SendPlay mode is deprecated. On Windows 11 and later, it may have no effect at all."

    __New(linter) {
        linter.OnEnter("hotstring_send_mode", (linter, node) {
            ; Hotstring in SendPlay mode
            if Trim(node.text) = "SP"
                linter.Report(SendPlayDeprecated.meta, node, SendPlayDeprecated.MESSAGE)
        })

        linter.OnEnter(["function_call", "call_statement"], (linter, node) {
            fn := node.GetChildByFieldName("function")
            ; Calls to SendPlay are always illegal
            if fn.text = "SendPlay" {
                linter.Report(SendPlayDeprecated.meta, fn, SendPlayDeprecated.MESSAGE)
                return
            }
            
            ; Check for SendMode("Play") or its call statement equivalent
            if fn.text = "SendMode" {
                argSeq := node.GetChildByFieldName("arguments")
                if argSeq.IsNull || (argSeq.NamedChildCount < 1)
                    return

                mode := FlattenNode(argSeq.GetNamedChild(0))
                if mode.IsNull || mode.type != "string_literal"
                    return

                unquoted := SubStr(Trim(mode.Text), 2, -1)
                if unquoted = "Play" || unquoted = "InputThenPlay" {
                    linter.Report(SendPlayDeprecated.meta, mode, SendPlayDeprecated.MESSAGE)
                    return
                }
            }
        })
    }

}