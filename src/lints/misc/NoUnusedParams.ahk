#Requires AutoHotkey v2.1-alpha.30 

#Import "../../lib/Util.ahk" { GetChildOfType }

class NoUnusedParams {
    static meta => {
        id:          "no-unused-params",
        title:       "No Unused Parameters",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  []
    }

    ; stack of seen frames - a frame is { params: Map<string, Node>, used: Map<string, _> }
    frames := []

    __New(linter) {
        linter.OnEnter("function_declaration", this.EnterFn.Bind(this))
        linter.OnEnter("method_declaration", this.EnterFn.Bind(this))
        linter.OnEnter("function_expression", this.EnterFn.Bind(this))
        linter.OnExit("function_declaration", this.ExitFn.Bind(this))
        linter.OnExit("method_declaration", this.ExitFn.Bind(this))
        linter.OnExit("function_expression", this.ExitFn.Bind(this))

        linter.OnEnter("identifier", this.SeeIdent.Bind(this))
    }

    EnterFn(_, node) => this.frames.Push({ params: NoUnusedParams.CollectParams(node), used: Map() })

    /**
     * identifier callback - if the identifier is a param, increment its use count
     * @param node 
     */
    SeeIdent(_, node) {
        if this.frames.Length <= 0 
            return

        nodeText := node.Text   ; node.Text is a DllCall behind the scenes, cache the response
        frame := this.frames[-1]

        if !frame.used.Has(nodeText)
            frame.used[nodeText] := 1
        else
            frame.used[nodeText]++
    }

    ExitFn(linter, _) {
        frame := this.frames.Pop()

        for name, paramNode in frame.params {
            if InStr(name, "_") == 1
                continue
            
            ; Expect each identifier param to appear more than once (1 for the declaration)
            if !frame.used.Has(name) || (frame.used[name] <= 1) {
                msg := Format("Parameter ``{1}`` is never used. If this is intentional, prefix it with an underscore: ``_{1}``", name)
                linter.Report(NoUnusedParams.meta, paramNode, msg)
            }
        }
    }

    /**
     * Given a function_declaration node, collects all parameters into a map of names to node objects
     * 
     * @param {Node} node the node
     * @returns {Map<String, Node>} map of node names to nodes for params 
     */
    static CollectParams(node) {
        params := Map()

        try paramSeq := GetChildOfType(node.GetChildByFieldName("head"), "param_sequence")
        if !IsSet(paramSeq) || paramSeq.IsNull {
            return params
        }

        current := paramSeq.GetNamedChild(0)

        while !current.IsNull {
            params[ExtractName(current)] := current
            current := current.NextNamedSibling
        }

        return params

        ; Helper to extract the name of a _param node
        ExtractName(node) {
            switch node.Type {
                case "identifier":
                    return node.Text
                case "optional_param", "default_param", "variadic_param":
                    return node.GetChildByFieldName("name").Text
                case "byref_param":
                    return ExtractName(node.GetChildByFieldName("param"))
                default:
                    throw ValueError("Unknown node type " node.Type)
            }
        }
    }
}