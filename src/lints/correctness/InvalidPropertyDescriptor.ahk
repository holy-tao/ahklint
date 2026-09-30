#Requires AutoHotkey v2.1-alpha.30

/**
 * Flags `DefineProp` descriptors that mix mutually exclusive forms (`Get`/`Set`/`Call`,
 * `Value`, and `Type`/`Pack`/`Offset`), hold properties `DefineProp` ignores, or pass a
 * literal `Pack` or `Offset` that can't be valid.
 */
class InvalidPropertyDescriptor {
    static meta => {
        id:          "invalid-property-descriptor",
        title:       "Invalid Property Descriptor",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/lib/Object.htm#DefineProp",
            "https://www.autohotkey.com/docs/alpha/lib/Object.htm#DefineProp"
        ]
    }

    /** The descriptor forms, for messages */
    static FORM_NAMES => Map(
        "accessor", "``Get``/``Set``/``Call``",
        "value",    "``Value``",
        "typed",    "``Type``/``Pack``/``Offset``"
    )

    /** Pack values DefineProp accepts */
    static PACK_VALUES := [0, 1, 2, 4, 8]

    __New(linter) {
        ; The free function DefineProp(obj, name, desc) arrived in v2.1-alpha.22
        this.hasFreeDefineProp := VerCompare(linter.ahkVersion, ">=2.1-alpha.22")

        ; Property name (lowercase) -> the descriptor form it belongs to. Older versions
        ; ignore the typed-property keys, so there they're unrecognized like any other.
        ; alpha.19 is a deliberately broad cutoff for typed properties, semantics churned quite
        ; a bit before this and aren't worth representing precisely
        this.forms := Map("get", "accessor", "set", "accessor", "call", "accessor", "value", "value")
        if VerCompare(linter.ahkVersion, ">=2.1-alpha.19") {
            this.forms["type"] := "typed"
            this.forms["pack"] := "typed"
        }
        if VerCompare(linter.ahkVersion, ">=2.1-alpha.24")
            this.forms["offset"] := "typed"

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
        if desc.Type == "object_literal"
            this.CheckDescriptor(linter, desc)
    }

    CheckDescriptor(linter, desc) {
        members := desc.GetNamedChildren().Filter(child => child.type = "object_literal_member")

        ; A dynamic %key% could be anything, so the descriptor can't be judged
        if members.Any(m => m.GetChildByFieldName("key").type != "identifier")
            return

        meta := InvalidPropertyDescriptor.meta
        formsUsed := Map()      ; form -> true, in first-seen order via `formOrder`
        formOrder := []
        hasType := false
        typedExtra := ""        ; the first Pack/Offset member, which needs a Type

        for member in members {
            key := member.GetChildByFieldName("key")
            name := StrLower(key.Text)

            if !this.forms.Has(name) {
                linter.Report(meta, member, Format("``{1}`` is not a property descriptor property, so ``DefineProp`` ignores it.", key.Text))
                continue
            }

            form := this.forms[name]
            if !formsUsed.Has(form) {
                formsUsed[form] := true
                formOrder.Push(form)
            }

            value := member.GetChildByFieldName("value")
            switch name {
                case "type":
                    hasType := true
                case "pack":
                    typedExtra := typedExtra || member
                    if problem := InvalidPropertyDescriptor.CheckPack(value)
                        linter.Report(meta, member, problem)
                case "offset":
                    typedExtra := typedExtra || member
                    if problem := InvalidPropertyDescriptor.CheckOffset(value)
                        linter.Report(meta, member, problem)
            }
        }

        if formOrder.Length > 1 {
            names := formOrder.Map(form => InvalidPropertyDescriptor.FORM_NAMES[form])
            message := names.Length == 2
                ? Format("Property descriptor mixes {1} with {2}, which are mutually exclusive.", names*)
                : Format("Property descriptor mixes {1}, {2} and {3}, which are mutually exclusive.", names*)
            linter.Report(meta, desc, message)
        }
        else if typedExtra && !hasType {
            linter.Report(meta, typedExtra, "``Pack`` and ``Offset`` define a typed property, which requires a ``Type``.")
        }
    }

    /** A message if a literal Pack value is invalid, else "" */
    static CheckPack(value) {
        switch value.Type {
            case "integer_literal", "hex_literal":
                n := Integer(value.Text)
                if InvalidPropertyDescriptor.PACK_VALUES.Any(val => val == n)
                    return ""
                return Format("``Pack`` must be 0, 1, 2, 4 or 8, not {1}.", value.Text)
            case "float_literal":
                return Format("``Pack`` must be 0, 1, 2, 4 or 8, not {1}.", value.Text)
            case "prefix_operation":
                if InvalidPropertyDescriptor.IsNegativeNumber(value)
                    return Format("``Pack`` must be 0, 1, 2, 4 or 8, not {1}.", value.Text)
        }
        return ""        
    }

    /** A message if a literal Offset value is invalid, else "". A string names another property. */
    static CheckOffset(value) {
        switch value.Type {
            case "float_literal":
                return Format("``Offset`` must be a whole number of bytes or a property name, not {1}.", value.Text)
            case "prefix_operation":
                if InvalidPropertyDescriptor.IsNegativeNumber(value)
                    return Format("``Offset`` must not be negative, but is {1}.", value.Text)
        }
        return ""
    }

    /** Whether `node` is a numeric literal with a leading minus, like `-1` */
    static IsNegativeNumber(node) {
        operand := node.GetChildByFieldName("operand")
        return SubStr(LTrim(node.Text), 1, 1) == "-"
            && operand.Type ~= "^(integer_literal|hex_literal|float_literal)$"
    }
}
