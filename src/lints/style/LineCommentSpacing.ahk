#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class LineCommentSpacing {
    static meta => {
        id:          "line-comment-spacing",
        title:       "Line Comment Spacing",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: true,
        references:  [],
        options: {
            allowEmpty: {
                type:           "boolean",
                default:        false,
                description:    "Whether empty line comments (just ``;``) are allowed"
            }
        }
    }

    __New(linter) {
        linter.OnEnter("line_comment", (linter, node) {
            allowEmpty := linter.Options(LineCommentSpacing.meta).allowEmpty
            nodeText := LTrim(node.text)

            ; check for empty comment and quit early, otherwise we'd double report
            if Trim(nodeText, " `r`n`t") == ";" {
                if !allowEmpty
                    linter.Report(LineCommentSpacing.meta, node, "Line comment is empty", Fix.To(node, ""))
                return
            }

            if SubStr(nodeText, 2, 1) == " " && !IsSpace(SubStr(nodeText, 3, 1))
                return

            comment := Trim(SubStr(nodeText, 2), " `r`n`t")
            linter.Report(LineCommentSpacing.meta, node, 
                "Line comments should start with exactly one space", Fix.To(node, "; " comment))
        })
    }
}