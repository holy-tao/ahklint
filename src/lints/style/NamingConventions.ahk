#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { GetChildOfType, FlattenNode, FirstNamedChildOfType }

; Patterns avoid nested quantifiers: `(?:[a-z0-9]+[A-Z]*)*` backtracks exponentially
; on names like `somereallylongname_x` and hits PCRE's match limit.

/**
 * Determine whether `str` is PascalCase
 * @param {String} str
 * @returns {Integer}
 */
IsPascalCase(str) => RegExMatch(str, "S)(*UCP)^_*\p{Lu}[\p{L}\d]*$")

/**
 * Determine whether `str` is camelCase
 * @param {String} str
 * @returns {Integer}
 */
IsCamelCase(str) => RegExMatch(str, "S)(*UCP)^_*\p{Ll}[\p{L}\d]*$")

/**
 * True if `str` is UPPER_SNAKE_CASE: an uppercase letter followed by uppercase
 * letters, digits, and underscores, with optional leading underscores
 * @param {String} str
 * @returns {Integer}
 */
IsUpperCase(str) => RegExMatch(str, "S)(*UCP)^_*\p{Lu}[\p{Lu}\d_]*$")

/**
 * True if the first non-underscore character of `str` has no case (e.g. CJK),
 * so neither style can apply to it
 * @param {String} str
 * @returns {Integer}
 */
IsCaseless(str) => !RegExMatch(str, "S)(*UCP)^_*[\p{Lu}\p{Ll}]")

/**
 * Enforce either camelCase or PascalCase names for various kinds
 * of identifiers.
 *
 * Every type is either "off" | "PascalCase" | "camelCase"
 */
class NamingConventions {
    static STYLES => ["off", "PascalCase", "camelCase"]

    /** Nodes which introduce a new variable scope */
    static SCOPE_NODES => ["function_declaration", "function_expression", "method_declaration", "fat_arrow_function", "property_declaration"]

    static meta => {
        id:          "naming-conventions",
        title:       "Naming Conventions",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: false,
        references:  [],
        options: {
            class: {
                type:        "string",
                default:     "PascalCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that classes should use."
            },
            struct: {
                type:        "string",
                default:     "PascalCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that structs should use."
            },
            function: {
                type:        "string",
                default:     "PascalCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that functions should use."
            },
            method: {
                type:        "string",
                default:     "PascalCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that methods should use."
            },
            property: {
                type:        "string",
                default:     "camelCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that properties should use."
            },
            variable: {
                type:        "string",
                default:     "camelCase",
                values:      NamingConventions.STYLES,
                description: "The naming convention that variables and parameters should use."
            },
        }
    }

    __New(linter) {
        opts := linter.Options(NamingConventions.meta)

        if opts.function != "off" {
            linter.OnEnter(["function_declaration", "function_expression", "fat_arrow_function"], (linter, node) {
                ; function expressions and fat arrows may be anonymous
                nameNode := node.GetChildByFieldName("name")
                if !nameNode.IsNull
                    this.CheckIdentifier("function", opts.function, linter, nameNode)
            })
        }

        if opts.method != "off" {
            linter.OnEnter("method_declaration", (linter, node) {
                this.CheckIdentifier("method", opts.method, linter, node.GetChildByFieldName("name"))
            })
        }

        if opts.class != "off" {
            linter.OnEnter("class_declaration", (linter, node) {
                this.CheckIdentifier("class", opts.class, linter, node.GetChildByFieldName("name"))
            })
        }

        if opts.struct != "off" {
            linter.OnEnter("struct_declaration", (linter, node) {
                this.CheckIdentifier("struct", opts.struct, linter, node.GetChildByFieldName("name"))
            })
        }

        if opts.property != "off" {
            static propertyKinds := ["property_declarator", "property_declaration", "typed_property_declaration"]
            linter.OnEnter(propertyKinds, (linter, node) {
                ; property_declarations with getter/setter blocks have direct names.
                ; Other forms have names under property_declarator nodes, which are
                ; checked on their own - but the field lookup on the declaration
                ; still finds the declarator's name, so skip it to avoid reporting twice
                if node.Type == "property_declaration" && !FirstNamedChildOfType(node, "property_declarator").IsNull
                    return

                nameNode := node.GetChildByFieldName("name")
                if nameNode.IsNull
                    return

                this.CheckIdentifier("property", opts.property, linter, nameNode)
            })

            linter.OnEnter("object_literal_member", (linter, node) {
                this.CheckIdentifier("property", opts.property, linter, node.GetChildByFieldName("key"))
            })
        }

        if opts.variable != "off" {
            ; Each scope holds the variable names already checked in it, so a variable
            ; assigned many times is reported once, at its first binding
            this.scopes := [NamingConventions.NewScope()]

            linter.OnEnter(NamingConventions.SCOPE_NODES, (linter, node) {
                this.scopes.Push(NamingConventions.NewScope())
                for param in NamingConventions.CollectParams(node)
                    this.CheckVariable(opts.variable, linter, param)
            })
            linter.OnExit(NamingConventions.SCOPE_NODES, (linter, node) => this.scopes.Pop())

            linter.OnEnter("assignment_operation", this.CheckAssignment.Bind(this, opts.variable))

            linter.OnEnter("variable_declarator", (linter, node) {
                this.CheckVariable(opts.variable, linter, node.GetChildByFieldName("name"))
            })

            linter.OnEnter("for_statement", (linter, node) {
                for iterator in node.GetChildrenByFieldName("iterator")
                    this.CheckVariable(opts.variable, linter, iterator)
            })

            linter.OnEnter("catch_clause", (linter, node) {
                variable := node.GetChildByFieldName("variable")
                if !variable.IsNull
                    this.CheckVariable(opts.variable, linter, variable)
            })
        }
    }

    /**
     * Check an assignment operation
     */
    CheckAssignment(style, linter, node) {
        ; compound assignments (+=, .=, ...) never introduce a variable
        if Trim(node.GetChildByFieldName("operator").Text) != ":="
            return

        left := FlattenNode(node.GetChildByFieldName("left")) ; (var) := "value" is legal
        if left.type != "identifier"
            return ; only check bare variable := "value" assignments, not member acess or anything

        this.CheckVariable(style, linter, left)
    }

    /**
     * Check a variable binding, unless a variable of the same name was already
     * checked in this scope or an enclosing one.
     */
    CheckVariable(style, linter, node) {
        name := Trim(node.Text, " `r`n`t")
        for scope in this.scopes {
            if scope.Has(name)
                return
        }

        this.scopes[-1][name] := true
        this.CheckIdentifier("variable", style, linter, node)
    }

    /**
     * Check that the identifier in `node` follows the given style.
     * @param {"class" | "struct" | "function" | "method" | "property" | "variable" } kind the node kind
     * @param {"PascalCase" | "camelCase" } style the style to check for
     * @param {Linter} linter the linter
     * @param {TreeSitter.Node} node node to check. Must be an identifier
     * @returns {void} nothing
     */
    CheckIdentifier(kind, style, linter, node) {
        ident := Trim(node.Text, " `r`n`t")

        ; UPPER_SNAKE is always allowed because we cannot reliably detect constants
        if IsUpperCase(ident) || IsCaseless(ident)
            return

        switch style {
            case "PascalCase": ok := IsPascalCase(ident)
            case "camelCase":  ok := IsCamelCase(ident)
            default:
                throw ValueError(Format("Unknown style '{1}'", style))
        }

        if !ok
            linter.Report(NamingConventions.meta, node, Format("{1} names should be {2}", StrTitle(kind), style))
    }

    /**
     * Create an empty, case-insensitive set of variable names
     * @returns {Map}
     */
    static NewScope() {
        scope := Map()
        scope.CaseSense := false
        return scope
    }

    /**
     * Given a function-like node or a property declaration, collects the name nodes
     * of all of its parameters.
     *
     * @param {Node} node the node
     * @returns {Array<Node>} the parameter name nodes
     */
    static CollectParams(node) {
        params := []

        ; properties have their parameters directly: `Item[index] => ...`
        head := node.Type == "property_declaration" ? node : node.GetChildByFieldName("head")
        if head.IsNull
            return params

        ; single-parameter fat arrow: `x => x`
        if head.Type == "identifier" {
            params.Push(head)
            return params
        }

        try paramSeq := GetChildOfType(head, "param_sequence")
        if !IsSet(paramSeq) || paramSeq.IsNull {
            return params
        }

        current := paramSeq.GetNamedChild(0)

        while !current.IsNull {
            if current.Type != "wildcard"
                params.Push(NameNode(current))
            current := current.NextNamedSibling
        }

        return params

        ; Helper to extract the name identifier of a _param node
        NameNode(node) {
            switch node.Type {
                case "identifier":
                    return node
                case "optional_param", "default_param", "variadic_param":
                    return node.GetChildByFieldName("name")
                case "byref_param":
                    return NameNode(node.GetChildByFieldName("param"))
                default:
                    throw ValueError("Unknown node type " node.Type)
            }
        }
    }
}
