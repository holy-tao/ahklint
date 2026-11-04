#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util" { IsConstExpr }

class LocalCanBeStatic {
    static meta => {
        id:          "local-can-be-static",
        title:       "Local Variable Could be Static",
        category:    "performance",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/Functions.htm#Local",
            "https://www.autohotkey.com/docs/v2/Functions.htm#static",
        ]
    }

    /**
     * List of built-in functions that:
     * a) are pure
     * b) don't return mutable objects (so not `StrSplit`, `Array` or `Map`)
     *
     * A call to any of these with constant arguments is assumed to be constant.
     */
    static PURE_BUILTINS := LocalCanBeStatic._NameSet(
        ; strings
        "Format", "StrLen", "SubStr", "StrReplace", "StrUpper", "StrLower", "StrTitle", "Trim", "LTrim",
        "RTrim", "InStr", "StrCompare", "RegExMatch", "RegExReplace", "Chr", "Ord", "Sort", "VerCompare",
        ; conversion and type checks
        "Integer", "Float", "Number", "String", "Type", "IsInteger", "IsFloat", "IsNumber", "IsDigit",
        "IsXDigit", "IsAlpha", "IsUpper", "IsLower", "IsAlnum", "IsSpace",
        ; math
        "Abs", "Ceil", "Floor", "Round", "Mod", "Sqrt", "Exp", "Ln", "Log", "Min", "Max", "Sin", "Cos",
        "Tan", "ASin", "ACos", "ATan"
    )

    ; Nodes that may skip the code inside them, or run it more than once
    static CONDITIONAL_TYPES := LocalCanBeStatic._NameSet(
        "if_statement", "else_statement", "loop_statement", "while_statement", "for_statement",
        "until_statement", "try_statement", "catch_clause", "finally_clause", "switch_statement",
        "case_clause", "default_clause", "ternary_expression", "logical_and_operation",
        "logical_or_operation", "or_maybe_operation"
    )

    __New(linter) {
        linter.scopes.OnComplete(this.Check.Bind(this))
    }

    Check(linter, scopes) {
        isPureCallee := LocalCanBeStatic.IsPureCallee.Bind(LocalCanBeStatic, scopes)

        for scope in scopes.all {
            ; Global variables may be read by other files, and a dynamic reference (`%name%`) may
            ; read or assign anything
            if scope.isGlobal || scope.hasDynamicRefs
                continue

            for name, variable in scope.variables {
                if variable.kind != "local" || variable.writes.Length != 1
                    continue

                ; `value` is only set for a plain `:=`, including `local x := ...`
                write := variable.writes[1]
                if !write.value
                    continue

                if !LocalCanBeStatic.RunsOncePerCall(write.node, scope)
                    continue

                if !IsConstExpr(write.value, isPureCallee)
                    continue

                msg := Format("Local variable ``{1}`` appears to be constant and can be made ``static``", name)
                linter.Report(LocalCanBeStatic.meta, write.node, msg)
            }
        }
    }

    /**
     * Whether `identifier` names a pure built-in function: it is on the allowlist and nothing in the
     * file declares or assigns that name where the call can see it (a user function, an import, or a
     * variable of the same name all shadow the built-in).
     */
    static IsPureCallee(scopes, identifier) {
        name := identifier.text
        if !LocalCanBeStatic.PURE_BUILTINS.Has(name)
            return false

        variable := scopes.ScopeOf(identifier).Lookup(name)
        return !variable || !(variable.declared || variable.writes.Length)
    }

    /**
     * Whether the statement holding `node` sits directly in the body of `scope`'s function, so it runs
     * exactly once on every call. A write inside a branch, loop, `try`, short-circuit or nested function
     * doesn't: the variable may be unset afterwards, which making it `static` would change.
     */
    static RunsOncePerCall(node, scope) {
        loop {
            node := node.Parent
            if node.IsNull
                return false
            if node.Equals(scope.node)
                return true

            if LocalCanBeStatic.CONDITIONAL_TYPES.Has(node.type)
                return false

            ; A block is only the function's own body if a function_body, or the function, holds it.
            ; Anything else (a bare `{ }`, a hotkey or nested function) is not this scope's body.
            switch node.type {
                case "block":
                    parent := node.Parent
                    if parent.type != "function_body" && !parent.Equals(scope.node)
                        return false
                case "function_declaration", "method_declaration", "function_expression",
                    "fat_arrow_function", "getter", "setter", "hotkey", "hotstring":
                    return false   ; some other function's body
            }
        }
    }

    static _NameSet(names*) {
        m := Map()
        m.CaseSense := false
        for name in names
            m[name] := true
        return m
    }
}
