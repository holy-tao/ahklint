#Requires AutoHotkey v2.1-alpha.30

class UntypedStructProperty {
    static meta => {
        id:          "untyped-struct-property",
        title:       "Untyped Struct Property",
        category:    "correctness",
        versions:    ">=2.1-alpha.22",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Structs.htm",
            "https://www.autohotkey.com/docs/alpha/lib/Struct.htm"
        ],
        tags: ["ffi"]
    }

    declStack := [false]

    inStructBody => this.declStack[-1]

    __New(linter) {
        linter.OnEnter("struct_body", (*) => this.declStack.Push(true))
        linter.OnEnter("class_body", (*) => this.declStack.Push(false))
        linter.OnExit(["class_body", "struct_body"], (*) => this.declStack.Pop())

        linter.OnEnter("property_declaration", this.CheckPropertyDeclarator.Bind(this))
    }

    CheckPropertyDeclarator(linter, node) {
        if !this.inStructBody
            return

        scope := node.GetChildByFieldName("scope")
        if !scope.IsNull && scope.text = "static"
            return

        if !node.GetChildByFieldName("body").IsNull
            return ; dynamic property, allowed

        linter.Report(UntypedStructProperty.meta, node, "Property initializers are illegal in struct definitions")
    }
}
