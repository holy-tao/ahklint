#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util" { IsComment }

class EmptyBlock {
    static meta => {
        id:          "empty-block",
        title:       "Empty Block",
        category:    "misc",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [],
        options: {
            allowComments: {
                type:        "boolean",
                default:     true,
                description: "If true, the lint won't fire for blocks that only contain comments"
            }
        }
    }

    __New(linter) {
        this.allowComments := linter.Options(EmptyBlock.meta).allowComments
        linter.OnEnter("block", (linter, node) {
            if node.GetNamedChildren().Any(child => this.allowComments || !IsComment(child))
                return
            linter.Report(EmptyBlock.meta, node, "This block is empty. Are you forgetting anything?")
        })
    }
}