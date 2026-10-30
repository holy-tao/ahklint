#Requires AutoHotkey v2.1-alpha.30
#Import "../../lib/Functions" { FUNCTION_NODES }
#Import "../../lib/Util" { StrJoin }

LOOP_NODES := [
    "while_statement",
    "for_statement",
    "loop_statement"
]

class FileAppendLoop {
    static meta => {
        id:          "fileappend-loop",
        title:       "FileAppend in Loop",
        category:    "performance",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/v2/lib/FileAppend.htm"]
    }

    ; A new scope is pushed for every function we enter, entering or exiting
    ; a loop we care about increments the depth counter here
    _scopes := [0]

    inAffectedLoop => this._scopes[-1] > 0

    __New(linter) {
        linter.OnEnter(FUNCTION_NODES, (*) => this._scopes.Push(0))
        linter.OnExit(FUNCTION_NODES, (*) => this._scopes.Pop())

        linter.OnEnter(LOOP_NODES, this.EnterLoopNode.Bind(this))
        linter.OnExit(LOOP_NODES, this.ExitLoopNode.Bind(this))

        linter.OnEnter(["function_call", "call_statement"], this.CheckCall.Bind(this))
    }

    CheckCall(linter, node) {
        if !this.inAffectedLoop || node.GetChildByFieldName("function").Text != "FileAppend" {
            return
        }

        linter.Report(FileAppendLoop.meta, node,
            "Open and close the file outside of the loop instead of calling FileAppend")
    }

    EnterLoopNode(_linter, node) {
        if FileAppendLoop.IsAffectedLoopNode(node)
            this._scopes[-1] += 1
    }

    ExitLoopNode(_linter, node) {
        if FileAppendLoop.IsAffectedLoopNode(node)
            this._scopes[-1] -= 1
    }

    static IsAffectedLoopNode(node) {
        ;@ahk2exe-ignorebegin
        if !LOOP_NODES.Any(nodeType => node.type = nodeType) {
            throw TypeError(Format("Expected node type to be among [{1}] but got '{2}'",
                StrJoin(", ", LOOP_NODES), node.type))
        }
        ;@ahk2exe-ignoreend

        if node.type = "loop_statement" {
            headNodes := node.GetChildrenByFieldName("head")
            if headNodes.length && headNodes[1].type = "read" && headNodes.length >= 3 {
                ; This is a `loop parse` with an output file, FileAppend is allowed (and preferred)
                return false
            }
        }

        return true
    }
}
