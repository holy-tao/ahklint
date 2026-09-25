#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }
#Import "../../lib/Util" { GetChildOfType, TryGetChildOfType, IsComment }

; TODO: fix grammar to give property declaration blocks fields. Change is mechanical once
; the grammar is fixed though

/**
 * Get all of the statements in a getter or setter block. If the getter or setter doesn't
 * have a block body (fat-arrow), returns an empty array.
 * 
 * @param {Node} node 
 * @returns {Array<Node>} the statements
 */
_Statements(node) {
    bodyBlock := _BodyOf(node)
    if bodyBlock.IsNull || bodyBlock.type != "block"
        return []

    return bodyBlock.GetNamedChildren()
        .Filter(child => !IsComment(child))
}

_GetterIsCollapsed(getter) {
    bodyBlock := _BodyOf(getter)
    return bodyBlock.IsNull || bodyBlock.type != "block"
}

_BodyOf(node) => GetChildOfType(node, "function_body").GetNamedChild(0)

/**
 * Convert a throw statement from statement form to function form
 * @param {Node} stmt throw_statement to convert 
 * @returns {String} 
 */
_ThrowStmtToFn(stmt) {
    ;@ahkbuild-ignorebegin
    if stmt.type != "throw_statement"
        throw TypeError("Expected a node of type 'throw_statement'", stmt.type, stmt)
    ;@ahkbuild-ignoreend

    thrown := stmt.GetChildByFieldName("thrown")
    return Format("throw({1})", thrown.IsNull ? "" : Trim(thrown.text))
}

class CollapsiblePropDecl {
    static meta => {
        id:          "collapsible-property-decl",
        title:       "Collapsible Property Declaration",
        category:    "complexity",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "auto",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/Objects.htm#Custom_Classes_property"
        ],
    }

    __New(linter) {
        ; In 2.1-alpha.3 and later, we can collapse throw statements to function calls
        ; See https://www.autohotkey.com/docs/alpha/lib/Throw.htm
        this.hasFunctionThrow := VerCompare(linter.ahkVersion, ">=2.1-alpha.3")

        linter.OnEnter("property_declaration_block", this.CheckPropertyDecl.Bind(this))
    }

    CheckPropertyDecl(linter, declBlock) {
        ; Note: either or both of getter and setter might be null
        getter := TryGetChildOfType(declBlock, "getter")
        setter := TryGetChildOfType(declBlock, "setter")

        if !getter.IsNull {
            collapsedGetter := this.CollapseGetter(getter)

            ; with a collapsible or already-collapsed getter but no setter, we can collapse the entire property
            ; to a `prop => Getter()` form.
            if setter.IsNull {
                if _GetterIsCollapsed(getter)
                    collapsedGetter := Trim(_BodyOf(getter).text)

                if collapsedGetter {
                    linter.Report(CollapsiblePropDecl.meta, declBlock.parent, "Property can be collapsed",
                        Fix.To(declBlock, "=> " collapsedGetter))
                    return
                }
            }

            if collapsedGetter {
                linter.Report(CollapsiblePropDecl.meta, getter, "Getter can be collapsed",
                    Fix.To(GetChildOfType(getter, "function_body"), " => " collapsedGetter))
            }
        }

        if !setter.IsNull {
            collapsedSetter := this.CollapseSetter(setter)
            if collapsedSetter {
                linter.Report(CollapsiblePropDecl.meta, setter, "Setter can be collapsed",
                    Fix.To(GetChildOfType(setter, "function_body"), " => " collapsedSetter))
            }
        }
    }

    /**
     * Collapse a getter to a single node. If the getter is collapsible, the node returned
     * is the returned value. A getter is collapsible if it's block-bodied and the block
     * has exactly one node, which is a return statement.
     *
     * @param {Node} getter the getter 
     * @returns {String} the text to collapse the getter to, empty if it can't collapse
     */
    CollapseGetter(getter) {
        ;@ahkbuild-ignorebegin
        if getter.type != "getter"
            throw TypeError("Expected a node of type 'getter'", getter.type, getter)
        ;@ahkbuild-ignoreend
        stmts := _Statements(getter)

        if stmts.length == 1 {
            stmt := stmts[1]

            if stmt.type == "return_statement" {
                ; Another lint should error if a getter doesn't return a value, it's allowed by the interpreter and
                ; we need to handle it gracefully
                returnedValue := stmts[1].GetChildByFieldName("value")
                if !returnedValue.IsNull
                    return Trim(returnedValue.text)
            }
            else if this.hasFunctionThrow && stmt.type == "throw_statement" {
                return _ThrowStmtToFn(stmt)
            }
        }

        return ""
    }

    /**
     * Collapse a setter to a single node. A setter is collapsible if it's block-bodied and
     * the block contains a exactly one node.
     *
     * @param {Node} setter the setter to check 
     * @returns {String} the text to collapse the setter to, empty if it can't collapse
     */
    CollapseSetter(setter) {
        ;@ahkbuild-ignorebegin
        if setter.type != "setter"
            throw TypeError("Expected a node of type 'setter'", setter.type, setter)
        ;@ahkbuild-ignoreend

        stmts := _Statements(setter)
        if stmts.length != 1
            return ""

        stmt := stmts[1]
        if this.hasFunctionThrow && stmt.type == "throw_statement" {
            return _ThrowStmtToFn(stmt)
        }
        else if stmt.type == "call_statement" {
            fn := Trim(stmt.GetChildByFieldName("function").Text)
            argsNode := stmt.GetChildByFieldName("arguments")
            args := argsNode.IsNull ? "" : Trim(argsNode.Text)

            return Format("{1}({2})", fn, args)
        }

        return Trim(stmt.text)
    }
}