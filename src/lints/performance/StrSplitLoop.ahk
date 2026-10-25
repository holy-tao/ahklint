#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/StringLiteral" { StringValue }
#Import "../../lib/Util.ahk" { StrJoin }

/**
 * Prefer `loop parse` over iterating the array `StrSplit` returns
 */
class StrSplitLoop {
    static meta => {
        id:          "strsplit-loop",
        title:       "Prefer Parsing Loops to StrSplit",
        category:    "performance",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/lib/LoopParse.htm",
            "https://www.autohotkey.com/docs/alpha/lib/StrSplit.htm"
        ]
    }

    /** Built-in variables that always hold exactly one character, so can stand in for a delimiter */
    static SINGLE_CHAR_VARS := "i)^A_(Space|Tab)$"

    __New(linter) {
        linter.OnEnter("for_statement", this.Evaluate.Bind(this))
    }

    Evaluate(linter, node) {
        call := StrSplitLoop.Unwrap(node.GetChildByFieldName("iterable"))
        if call.type != "function_call"
            return

        callee := call.GetChildByFieldName("function")
        if callee.type != "identifier" || callee.text != "StrSplit"
            return

        argSeq := call.GetChildByFieldName("arguments")
        if argSeq.IsNull || argSeq.NamedChildCount > 4
            return

        args := []
        loop argSeq.NamedChildCount {
            arg := argSeq.GetNamedChild(A_Index - 1)
            if arg.type == "array_expansion_operation"
                return                                  ; StrSplit(args*): can't tell what it gets
            args.Push(arg)
        }

        ; Parsing loops have no MaxParts. -1, its default, is the only value that changes nothing
        if args.Length == 4 && args[4].type != "empty_arg" && RegExReplace(args[4].text, "\s") != "-1"
            return

        if !StrSplitLoop.DelimiterChars(args.Length >= 2 ? args[2] : unset, &delimiters)
            return

        suggestion := "loop parse " args[1].text
        if args.Length >= 3 && args[3].type != "empty_arg"
            suggestion .= ", " delimiters ", " args[3].text
        else if delimiters != ""
            suggestion .= ", " delimiters

        linter.Report(StrSplitLoop.meta, call,
            Format("Use a parsing loop instead of iterating over the array StrSplit creates: ``{1}``", suggestion))
    }

    /**
     * Source text for the parsing loop's DelimiterChars equivalent to StrSplit's Delimiters, if there is one.
     *
     * StrSplit splits on each delimiter string as a whole, where a parsing loop splits on each character of its
     * delimiter string (and treats `"CSV"` as a keyword), so they only agree when every delimiter is one
     * character long.
     *
     * @param {Node} arg the Delimiters argument; unset if it was left out
     * @param {VarRef<String>} out receives the source text, empty to leave DelimiterChars out
     * @returns {Boolean} whether there is an equivalent
     */
    static DelimiterChars(arg?, &out?) {
        out := ""
        if !IsSet(arg) || arg.type == "empty_arg"
            return true

        arg := StrSplitLoop.Unwrap(arg)
        if arg.type == "string_literal" {
            value := StringValue(arg).value
            if StrLen(value) > 1
                return false
            out := value == "" ? "" : arg.text
            return true
        }

        if arg.type != "array_literal"
            return false

        elements := arg.GetChildByFieldName("elements")
        if elements.IsNull
            return false                                ; StrSplit(s, []) has no delimiters at all

        parts := []
        loop elements.NamedChildCount {
            element := StrSplitLoop.Unwrap(elements.GetNamedChild(A_Index - 1))
            if element.type == "string_literal" && StrLen(StringValue(element).value) == 1
                parts.Push(element.text)
            else if element.type == "identifier" && element.text ~= StrSplitLoop.SINGLE_CHAR_VARS
                parts.Push(element.text)
            else
                return false
        }
        out := StrJoin(" ", parts*)
        return true
    }

    /** Drill through redundant parentheses: `((x))` -> `x` */
    static Unwrap(node) {
        while (node.type == "parenthesized_expression" || node.type == "expression_sequence")
            && node.NamedChildCount == 1
            node := node.GetNamedChild(0)
        return node
    }
}
