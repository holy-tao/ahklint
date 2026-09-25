#Requires AutoHotkey v2.1-alpha.30

#Import treesitter { Tree }
#Import "../../Diagnostic" { Fix }

/**
 * Checks for control-flow statements that do or do not use parentheses, depending on
 * its configuration. Parentheses are optional, this lint exists to let users (me) force
 * people to use one form or another.
 */
class ControlFlowParentheses {
    static meta => {
        id:          "control-flow-parentheses",
        title:       "Control Flow Parentheses",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: false,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Language.htm#control-flow"
        ],
        options: {
            style: {
                type:        "string",
                default:     "forbidden",
                values:      ["required", "forbidden"],
                description: "Whether quotes in control flow statements are required or forbidden."
            }
        }
    }

    /**
     * Construct the user-facing message for a lint violation
     * @param {string} replacement the replacement text for the fix
     * @returns {String} 
     */
    Message(replacement) => 
        Format("Control flow statements should {1} parentheses: ``{2}``", 
            this.style = "required" ? "use" : "not use", replacement)

    __New(linter) {
        this.style := linter.Options(ControlFlowParentheses.meta).style

        linter.OnEnter(["if_statement", "while_statement", "until_statement"],
            (linter, node) => this.CheckSimple(linter, node, "condition"))
        linter.OnEnter("switch_statement", (linter, node) => this.CheckSimple(linter, node, "head"))
        linter.OnEnter("for_statement", (linter, node) => this.CheckRegex(linter, node, "for"))
        linter.OnEnter("catch_clause", (linter, node) => this.CheckRegex(linter, node, "catch"))
    }

    /**
     * If, while, switch, and until statements take an arbitrary expression
     * which might be a parenthesized_expression, so they're relatively straightforward
     * to check. For loops and catch clauses are more structured so they're more complicated
     */
    CheckSimple(linter, node, fieldName) {
        head := node.GetChildByFieldName(fieldName)
        isParens := head.type == "parenthesized_expression"

        if isParens && this.style = "forbidden" {
            ; Without parentheses we need to take care to separate the condition from the keyword with a space
            keyword := SubStr(node.text, 1, InStr(node.text, "(") - 1)
            hasTrailingSpace := IsSpace(SubStr(keyword, -1))

            patch := Fix.To(head, Format("{1}{2}", hasTrailingSpace ? "" : " ", head.GetNamedChild(0).text))
            linter.Report(ControlFlowParentheses.meta, head, this.Message(patch.newText), patch)
        }
        else if !isParens && this.style = "required" {
            patch := Fix.To(head, Format("({1})", head.text))
            linter.Report(ControlFlowParentheses.meta, head, this.Message(patch.newText), patch)
        }
    }

    CheckRegex(linter, node, keyword) {
        ; collect the "head" nodes (everything up to the block) - this *includes* anonymous children so that
        ; it captures the parentheses if they exist. This will also capture the "for" keyword itself.
        headNodes := []
        loop node.ChildCount {
            if node.GetFieldNameForChild(A_Index - 1) == "body"
                break
            headNodes.Push(node.GetChild(A_Index - 1))
        }

        startByte := headNodes[1].startByte, endByte := headNodes[-1].endByte
        treeInfo := Tree.InfoOf(node.tree)
        headText := StrGet(treeInfo.source.Ptr + startByte, endByte - startByte, treeInfo.encoding)

        isParens := RegExMatch(headText, "S)" keyword "\s*\((?<iter>.+)\)", &match := "")
        if isParens && this.style == "forbidden" {
            patch := Fix(startByte, endByte, Format("{1} {2}", keyword, match.iter))
            linter.Report(ControlFlowParentheses.meta, node, this.Message(patch.newText), patch)
        }
        else if !isParens && this.style == "required" {
            patch := Fix(startByte, endByte, Format("for ({1})", Trim(SubStr(headText, StrLen(keyword) + 1))))
            linter.Report(ControlFlowParentheses.meta, node, this.Message(patch.newText), patch)
        }
    }
}
