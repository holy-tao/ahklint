#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode, GetArg }

class NoPriorityChanges {
    static meta => {
        id:          "no-priority-changes",
        title:       "Do Not Change Thread Priority",
        category:    "threading",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/misc/Threads.htm",
            "https://www.autohotkey.com/docs/alpha/lib/Thread.htm#Priority"
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
        if (subFunction.Type == "string_literal") && InStr(subFunction.Text, "priority") {
            linter.Report(NoPriorityChanges.meta, node, 
                "Threads starting at a lower priority are dropped, not buffered. Use ``Critical`` for uninterruptible operations.")
        }
    }
}