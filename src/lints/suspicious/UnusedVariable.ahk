#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "../../Diagnostic" { Fix }

class UnusedVariable {
    static meta => {
        id:          "unused-variable",
        title:       "Unused Variable",
        category:    "suspicious",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: true,
        references:  []
    }

    __New(linter) {
        linter.scopes.OnComplete(this.Check.Bind(this))
    }

    Check(linter, scopes) {
        for scope in scopes.all {
            ; Global variables may be read by other files, and a dynamic reference (`%name%`) may
            ; read anything
            if scope.isGlobal || scope.hasDynamicRefs
                continue

            for name, variable in scope.variables {
                if variable.kind != "local" && variable.kind != "static"
                    continue   ; parameters are unused-param's, functions and the like aren't variables
                if InStr(name, "_") == 1
                    continue
                if UnusedVariable.IsRead(variable)
                    continue

                anchor := variable.declaration || variable.writes[1].node
                msg := variable.writes.Length
                    ? Format("``{1}`` is assigned a value but never read", name)
                    : Format("``{1}`` is declared but never used", name)
                msg .= Format(". If this is intentional, prefix it with an underscore: ``_{1}``", name)
                linter.Report(UnusedVariable.meta, anchor, msg, UnusedVariable.Rename(variable, "_" name))
            }
        }
    }

    /**
     * Whether anything reads the variable, other than to update it. Passing it by reference counts:
     * whoever gets the reference may read through it.
     */
    static IsRead(variable) {
        for write in variable.writes {
            if write.node.Parent.type == "varref_operation"
                return true
        }
        for read in variable.reads {
            if !UnusedVariable.IsSelfRead(variable, read)
                return true
        }
        return false
    }

    /**
     * Whether `read` only feeds a new value of the same variable, which nothing then reads: `x++`,
     * `x += 1` or `x := x + 1` used as a statement
     */
    static IsSelfRead(variable, read) {
        for write in variable.writes {
            if write.node.Equals(read)
                return UnusedVariable.IsDiscarded(write.node.Parent)   ; `x++`, `x .= y`

            value := write.value
            if value && value.StartByte <= read.StartByte && read.EndByte <= value.EndByte
                return UnusedVariable.IsDiscarded(value.Parent)        ; `x := x + 1`
        }
        return false
    }

    /** Whether nothing uses the value of an expression, because it is a statement of its own */
    static IsDiscarded(expr) {
        parent := expr.Parent
        switch parent.type {
            case "block", "source_file", "else_statement":
                return true
            case "fat_arrow_function":
                return false   ; its body is the return value
        }
        return parent.GetChildByFieldName("body").Equals(expr)   ; `if c`, `loop`, `^a::` ...
    }

    /** Rename every occurrence of a variable */
    static Rename(variable, newName) {
        fixes := [], seen := Map()
        nodes := variable.writes.Map(write => write.node)
        nodes.Push(variable.reads*)
        if variable.declaration
            nodes.Push(variable.declaration)

        for node in nodes {
            if seen.Has(node.StartByte)
                continue
            seen[node.StartByte] := true
            fixes.Push(Fix.To(node, newName))
        }
        return fixes
    }
}
