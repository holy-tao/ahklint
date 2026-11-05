#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FirstNamedChildOfType }

class DuplicateClassMember {
    static meta => {
        id:          "duplicate-class-member",
        title:       "Duplicate Class Member",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/Objects.htm#Custom_Classes",
            "https://www.autohotkey.com/docs/alpha/Structs.htm"
        ]
    }

    static Msg(name, isLocal) => Format("Duplicate {1} class member name ``{2}``",
        isLocal ? "instance" : "static", name)

    ; A case-insensitive set of member names
    static NameSet() {
        names := Map()
        names.CaseSense := "Off"
        return names
    }

    _stack := []

    __New(linter) {
        static CLASS_NODES := ["class_declaration", "struct_declaration"]
        static MEMBER_NODES := ["typed_property_declaration", "method_declaration", "property_declaration"]

        linter.OnEnter(CLASS_NODES, (*) => this._stack.Push({
            locals: DuplicateClassMember.NameSet(),
            statics: DuplicateClassMember.NameSet()
        }))
        linter.OnExit(CLASS_NODES, (*) => this._stack.Pop())

        ; `static a := 1, b := 2` is one property_declaration holding several declarators.
        linter.OnEnter("property_declarator", (linter, node) {
            this.Check(linter, node, node.GetChildByFieldName("name"), node.Parent)
        })

        linter.OnEnter(MEMBER_NODES, (linter, node) {
            if node.Type == "property_declaration" && !FirstNamedChildOfType(node, "property_declarator").IsNull
                return

            this.Check(linter, node, node.GetChildByFieldName("name"), node)
        })
    }

    ; Records `nameNode` as a member, or reports `node` if the name was already taken by a member
    ; of the same staticness. `scopeOwner` is the node carrying the `scope` (static) field.
    Check(linter, node, nameNode, scopeOwner) {
        if nameNode.IsNull
            return

        isLocal := scopeOwner.GetChildByFieldName("scope").IsNull
        seen := isLocal ? this._stack[-1].locals : this._stack[-1].statics
        name := nameNode.text

        if seen.Has(name) {
            linter.Report(DuplicateClassMember.meta, node, DuplicateClassMember.Msg(name, isLocal))
        } else {
            seen.Set(name, 1)
        }
    }
}
