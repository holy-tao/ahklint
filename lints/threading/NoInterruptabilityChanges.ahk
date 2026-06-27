#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode, GetArg }

class NoInterruptabilityChanges {
    static meta => {
        id:          "no-interrupt-changes",
        title:       "Do Not Change Thread Interruptability",
        category:    "threading",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/misc/Threads.htm",
            "https://www.autohotkey.com/docs/alpha/lib/Thread.htm#Interrupt"
        ]
    }

    __New(linter) {
        linter.OnEnter("function_call", this.Evaluate.Bind(this))
        linter.OnEnter("call_statement", this.Evaluate.Bind(this))
    }

    Evaluate(linter, node) {
        if node.GetChildByFieldName("function").Text != "Thread" {
            return
        }
        
        if !(subFunction := GetArg(node, 0))
            return

        subFunction := FlattenNode(subFunction)
        if (subFunction.Type == "string_literal") && InStr(subFunction.Text, "interrupt") {
            linter.Report(NoInterruptabilityChanges.meta, node, 
                "Most scripts perform more consistently with default thread interrupt settings.")
        }
    }
}