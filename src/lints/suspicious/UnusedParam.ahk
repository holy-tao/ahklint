#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Functions" { CollectParams, FUNCTION_NODES }
#Import "../../Diagnostic" { Fix }

class UnusedParam {
    static meta => {
        id:          "unused-param",
        title:       "Unused Parameter",
        category:    "suspicious",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: true,
        references:  []
    }

    ; stack of seen frames - a frame is { params: Map<string, Node>, used: Map<string, _> }
    frames := []

    __New(linter) {
        linter.OnEnter(FUNCTION_NODES, this.EnterFn.Bind(this))
        linter.OnExit(FUNCTION_NODES, this.ExitFn.Bind(this))

        linter.OnEnter("identifier", this.SeeIdent.Bind(this))
        this.frames.Capacity := 24
    }

    EnterFn(_, node) => this.frames.Push({ params: CollectParams(node), used: Map() })

    /**
     * identifier callback - if the identifier is a param, increment its use count
     * @param node
     */
    SeeIdent(_, node) {
        if this.frames.Length <= 0
            return

        nodeText := node.Text   ; node.Text is a DllCall behind the scenes, cache the response

        ; Walk up the frame stack so that a closure's use of an outer function's
        ; param counts for that outer function. The innermost frame that declares
        ; the name wins, since an inner param of the same name shadows the outer one.
        frame := this.frames[-1]
        i := this.frames.Length
        while i >= 1 {
            if this.frames[i].params.Has(nodeText) {
                frame := this.frames[i]
                break
            }
            i--
        }

        frame.used.Set(nodeText, frame.used.Get(nodeText, 0) + 1)
    }

    ExitFn(linter, _) {
        frame := this.frames.Pop()

        for name, paramNode in frame.params {
            ; Expect each identifier param to appear more than once (1 for the declaration)
            if frame.used.Get(name, 0) <= 1 && InStr(name, "_") != 1 {
                msg := Format("Parameter ``{1}`` is never used. If this is intentional, prefix it with an underscore: ``_{1}``", name)
                linter.Report(UnusedParam.meta, paramNode, msg, Fix.To(paramNode, "_" name))
            }
        }
    }
}
