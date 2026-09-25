#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

class ConcatStyle {
    static meta => {
        id:          "concat-style",
        title:       "Concatenation Style",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: false,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Variables.htm#concat"
        ],
        options: {
            style: {
                type:        "string",
                default:     "implicit",
                values:      ["implicit", "explicit"],
                description: "The style that string concatenations should use."
            },
            requireExplicitForNonLiteral: {
                type:        "boolean",
                default:     false,
                description: "Require explicit concatenation operators when neither operand is a string literal."
                    . " This has no effect when style is `"explicit`"."
            }
        }
    }

    /**
     * Node types whose contents are joined by continuation-by-enclosure, so a line break
     * inside them doesn't need a leading or trailing operator.
     */
    static ENCLOSURES := "^(parenthesized_expression|function_call|index_access|array_literal|object_literal)$"

    /**
     * Node types that hold statements. A concatenation inside one of these is not enclosed
     * by anything outside it, e.g. a block inside a function expression passed as an argument.
     */
    static STATEMENT_CONTAINERS := "^(block|function_body|class_body|struct_body|switch_body|property_declaration_block)$"

    __New(linter) {
        opts := linter.Options(ConcatStyle.meta)
        this.style := opts.style
        this.requireExplicitForNonLiteral := opts.requireExplicitForNonLiteral

        linter.OnEnter("explicit_concat_operation", this.Check.Bind(this, true))
        linter.OnEnter("implicit_concat_operation", this.Check.Bind(this, false))
    }

    Check(isExplicit, linter, node) {
        left := node.GetChildByFieldName("left")
        right := node.GetChildByFieldName("right")
        if left.IsNull || right.IsNull
            return

        wantExplicit := this.WantsExplicit(left, right)
        if wantExplicit = isExplicit
            return

        ; edit only the gap between the operands, so nested concats get disjoint fixes
        if wantExplicit {
            message := this.style = "explicit"
                ? "Use explicit concatenation"
                : "Use explicit concatenation when neither operand is a string literal"
            linter.Report(ConcatStyle.meta, node, message, Fix(left.endByte, right.startByte, " . "))
            return
        }

        ; outside an enclosure, the operator is what continues the line
        if left.endPoint.row != right.startPoint.row && !ConcatStyle.IsEnclosed(node)
            return

        ; dropping the dot would change the meaning when the right side opens with an operator, e.g. x . -y
        if right.text ~= "^[-+&!~]" {
            return
        }

        ; the operator token includes the whitespace around the dot. Delete the dot and the whitespace
        ; on the side that shares its line, keeping any line break and indentation
        operator := node.GetChildByFieldName("operator")
        dotPos := InStr(operator.text, ".")
        dotByte := operator.startByte + dotPos - 1
        patch := SubStr(operator.text, dotPos + 1) ~= "[\r\n]"
            ? Fix(operator.startByte, dotByte + 1, "")
            : Fix(dotByte, operator.endByte, "")
        linter.Report(ConcatStyle.meta, node, "Use implicit concatenation", patch)
    }

    WantsExplicit(left, right) {
        if this.style = "explicit"
            return true
        if !this.requireExplicitForNonLiteral
            return false

        return ConcatStyle.Adjacent(left, "right").type != "string_literal"
            && ConcatStyle.Adjacent(right, "left").type != "string_literal"
    }

    /**
     * The operand that touches the operator. In `a "x" b` the outer concat's left child is
     * `a "x"`, but the operand next to the operator is `"x"`.
     */
    static Adjacent(node, side) {
        while node.type ~= "_concat_operation$"
            node := node.GetChildByFieldName(side)
        return node
    }

    /**
     * Whether the node sits inside parentheses, brackets, or braces that continue lines on
     * their own, e.g. `MsgBox(1 \n . 2)`.
     */
    static IsEnclosed(node) {
        loop {
            node := node.Parent
            if node.IsNull
                return false
            if node.type ~= ConcatStyle.ENCLOSURES
                return true
            if node.type ~= ConcatStyle.STATEMENT_CONTAINERS
                return false
        }
    }
}
