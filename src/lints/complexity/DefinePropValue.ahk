#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

/**
 * Flags `obj.DefineProp("prop", { Value: x })` (and the v2.1 free-function form),
 * which is a verbose `obj.prop := x` unless overwriting an existing property is the point.
 */
class DefinePropValue {
    static meta => {
        id:          "define-prop-value",
        title:       "DefineProp With Only a Value",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",  ; assignment runs __Set and setters; DefineProp replaces them
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/Object.htm#DefineProp",
            "https://www.autohotkey.com/docs/alpha/lib/Object.htm#DefineProp"
        ]
    }

    static message => "``DefineProp`` with only a ``Value`` is equivalent to assigning the property, unless you mean to overwrite an existing one."

    __New(linter) {
        ; The free function DefineProp(obj, name, desc) arrived in v2.1-alpha.22
        this.hasFreeDefineProp := VerCompare(linter.ahkVersion, ">=2.1-alpha.22")

        linter.OnEnter(["function_call", "call_statement"], this.Evaluate.Bind(this))
    }

    Evaluate(linter, node) {
        callee := node.GetChildByFieldName("function")

        ; obj.DefineProp(name, desc) - the descriptor is the second argument.
        ; DefineProp(obj, name, desc) - the descriptor is the third.
        if callee.Type == "member_access" {
            member := callee.GetChildByFieldName("member")
            if !(member.Type == "identifier" && member.Text = "DefineProp")
                return
            descIndex := 1
        }
        else if this.hasFreeDefineProp && callee.Type == "identifier" && callee.Text = "DefineProp" {
            descIndex := 2
        }
        else {
            return
        }

        args := node.GetChildByFieldName("arguments")
        if args.IsNull || args.NamedChildCount <= descIndex
            return

        desc := args.GetNamedChild(descIndex)
        if !(desc.Type == "object_literal" && DefinePropValue.IsValueOnly(desc))
            return

        target := descIndex == 1 ? callee.GetChildByFieldName("object") : args.GetNamedChild(0)
        name := args.GetNamedChild(descIndex - 1)
        if patch := DefinePropValue.SuggestAssignment(node, target, name, desc)
            linter.Report(DefinePropValue.meta, node, DefinePropValue.message, [patch])
        else
            linter.Report(DefinePropValue.meta, node, DefinePropValue.message)
    }

    /**
     * The fix rewriting the call as `target.name := value`, or "" if it can't be
     * rewritten safely. The call must be a statement on its own: `DefineProp` returns
     * the object but `:=` returns the value, so a call whose result is used can't change.
     */
    static SuggestAssignment(call, target, name, desc) {
        if !DefinePropValue.IsDiscarded(call)
            return ""
        if target.Type ~= "^(empty_arg|array_expansion_operation)$" || name.Type ~= "^(empty_arg|array_expansion_operation)$"
            return ""

        ; The last `Value` wins if there are several, the same as for the call
        value := desc.GetNamedChildren()
            .Last(child => child.type = "object_literal_member")
            .GetChildByFieldName("value")
            .text

        ; `obj.name` for a literal name that's a plain identifier, else `obj.%name%`
        if name.Type == "string_literal" && RegExMatch(name.Text, "^([`"'])([A-Za-z_]\w*)\1$", &m)
            member := "." m[2]
        else
            member := ".%" name.Text "%"

        obj := target.Text
        if !(target.Type ~= DefinePropValue.MEMBER_SAFE)
            obj := "(" obj ")"

        return Fix.To(call, obj member " := " value)
    }

    /** Node types that can take `.name` directly, without wrapping in parentheses */
    static MEMBER_SAFE := "^(identifier|member_access|index_access|function_call|parenthesized_expression)$"

    /** Node types that run their `body` field as a statement */
    static STATEMENT_BODIES := "^(if_statement|else_statement|loop_statement|while_statement|for_statement|try_statement|catch_clause|finally_clause|case_clause|default_clause|hotkey)$"

    /**
     * Node types whose children are statements. Not `function_body`: a braced body holds
     * a `block`, so an expression directly under one is the return value of `f() => expr`.
     */
    static STATEMENT_CONTAINERS := "^(source_file|block)$"

    /**
     * Whether the value of `node` is thrown away: it is a statement, or one item of a
     * comma-separated sequence that is itself a statement.
     */
    static IsDiscarded(node) {
        if node.Type == "call_statement"
            return true

        parent := node.Parent
        while parent.Type == "expression_sequence" {
            node := parent
            parent := node.Parent
        }

        if parent.Type ~= DefinePropValue.STATEMENT_CONTAINERS
            return true
        return parent.Type ~= DefinePropValue.STATEMENT_BODIES
            && parent.GetChildByFieldName("body").Equals(node)
    }

    /**
     * Whether an object literal descriptor has a `Value` and nothing else. Any other
     * key (`Get`, `Set`, `Call`, `Type`, or a dynamic `%key%`) means the descriptor is
     * doing something plain assignment can't.
     */
    static IsValueOnly(desc) {
        return desc
            .GetNamedChildren()
            .Filter(child => child.type = "object_literal_member")
            .Map(member => member.GetChildByFieldName("key"))
            .All(key => key.type = "identifier" && key.text = "value")
    }
}
