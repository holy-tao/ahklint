#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util" { FlattenNode, IsComment }


class CollapsibleIf {
    static meta => {
        id:          "collapsible-if",
        title:       "Collapsible If Statement",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [],
        options: {
            allowComments: {
                type:        "boolean",
                default:     true,
                description: "Whether the lint should fire if the block that would be collapsed contains comments"
            }
        }
    }

    __New(linter) {
        this.allowComments := linter.Options(CollapsibleIf.meta).allowComments
        linter.OnEnter("if_statement", this.CheckIfStatement.Bind(this))
    }

    CheckIfStatement(linter, node) {
        body := FlattenNode(node.GetChildByFieldName("body"))
        if body.type == "block" {
            bodyChildren := body
                .GetNamedChildren()
                .Filter(child => this.allowComments || !IsComment(child))

            if bodyChildren.Length != 1
                return
            body := bodyChildren[1]
        }

        if body.type != "if_statement" || !body.GetChildByFieldName("else_block").IsNull
            return

        ; TODO check to see if either side needs to be parenthesized?
        topCondition := Trim(node.GetChildByFieldName("condition").text, " `r`n`t")
        nestedCondition := Trim(body.GetChildByFieldName("condition").text, " `r`n`t")
        newCondition := topCondition " && " nestedCondition

        linter.Report(CollapsibleIf.meta, node,
            Format("If statements can be collapsed: ``if {1}``", newCondition))
    }
}