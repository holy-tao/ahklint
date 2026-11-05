#Requires AutoHotkey v2.1-alpha.30

class DuplicateObjectKey {
    static meta => {
        id:          "duplicate-object-key",
        title:       "Duplicate Object Key",
        category:    "correctness",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  []
    }

    __New(linter) {
        linter.OnEnter("object_literal", this.Check.Bind(this))
    }

    Check(linter, node) {
        seen := Map(), seen.CaseSense := "Off"

        for member in node.GetNamedChildren("object_literal_member") {
            key := member.GetChildByFieldName("key")
            if key.IsNull
                continue

            key := key.text

            if seen.Has(key) {
                linter.Report(DuplicateObjectKey.meta, member, "Duplicate object literal key ``" key "``")
            } else {
                seen.Set(key, 1)
            }
        }
    }
}
