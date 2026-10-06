#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "collections/Set" { Set }
#Import "./Util" { TryGetChildOfType }

/**
 * Variable scopes: which variables a file has, where each is assigned, and where each is read.
 *
 * A lint gets the tracker from `linter.scopes` in its constructor and registers an `OnComplete` callback.
 * Which variable a name refers to can depend on code further down the file (a nested function shares
 * a variable its outer function assigns later), so names are only bound to variables once the whole
 * file has been walked. Don't read `Scope.variables` before then.
 */

/**
 * One variable.
 *
 * `kind` is how it came to exist: "global", "local" or "static" for ordinary variables, "param",
 * "function" (a function declaration), "class", "import", or "implicit" (`this`, a setter's `value`,
 * a hotkey's `ThisHotkey`).
 */
export class Variable {
    /** Whether something declares the variable, as opposed to it only being assigned or read */
    declared := false

    /**
     * The identifier that declares the variable, or an empty string
     * @type {Node | String}
     */
    declaration := ""

    /**
     * Every place the variable may be given a value. `node` is the identifier written to. `value` is the
     * expression assigned by a plain `:=`, or an empty string when the new value isn't an expression in
     * the source (`.=`, `++`, `&var`, a `for` loop or `catch` variable).
     * @type {Array<{node: Node, value: Node | String}>}
     */
    writes := []

    /**
     * Every identifier that reads the variable
     * @type {Array<Node>}
     */
    reads := []

    __New(name, kind) {
        this.name := name
        this.kind := kind
    }
}

/**
 * The global scope, or the scope of one function. Classes and blocks don't have scopes of their own.
 */
export class Scope {
    /**
     * The variables this scope owns, by name. Complete once the file has been walked.
     * @type {Map<String, Variable>}
     */
    variables := Scope._NameMap()

    /** Names this function declares `global` */
    globals := Scope._NameMap()

    /** Whether the function is assume-global (a bare `global` declaration) */
    assumeGlobal := false

    /** Whether the function is assume-static (a bare `static` declaration) */
    assumeStatic := false

    /**
     * Whether this is a nested function declared `static`, which can't capture the non-static
     * variables of the functions around it
     */
    isStatic := false

    /**
     * Whether a dynamic reference (`%name%`) in this scope or a function nested in it might read or
     * assign this scope's variables in a way the tracker can't see
     */
    hasDynamicRefs := false

    /**
     * @param {Node | String} node the node that opens the scope, or an empty string for the global scope
     * @param {Scope | String} outer the function whose variables this one can capture, if any
     * @param {Scope | String} root the global scope, or an empty string if this is it
     */
    __New(node, outer, root) {
        this.node := node
        this.outer := outer
        this.root := root
    }

    isGlobal => !this.root

    /**
     * The scope owning the variable that `name` refers to when used in this scope.
     * @returns {Scope}
     */
    OwnerOf(name) => this._OwnerOf(name, false)

    /**
     * The variable `name` refers to when used in this scope.
     * @returns {Variable | String} an empty string if nothing in the file declares, assigns or reads it
     */
    Lookup(name) => this.OwnerOf(name).variables.Get(name, "")

    /**
     * @param {Boolean} nested whether a nested function is asking. It only sees the name if this function
     *        makes it a variable of its own; a name this function merely reads isn't captured.
     * @param {Boolean} staticOnly whether the asker is, or is nested in, a `static` function. It only
     *        sees this function's static variables.
     */
    _OwnerOf(name, nested, staticOnly := false) {
        root := this.root || this
        if this.globals.Has(name)
            return root
        if this.variables.Has(name) && this.variables[name].declared
            return !staticOnly || this._IsStatic(this.variables[name]) ? this : ""
        if this.outer && (owner := this.outer._OwnerOf(name, true, staticOnly || this.isStatic))
            return owner
        if this.isGlobal || this.assumeGlobal
            return root

        ; Assume-local: assigning a name makes it local, only reading it reaches for a global
        if this.variables.Has(name) && this.variables[name].writes.Length
            return !staticOnly || this.assumeStatic ? this : ""
        return nested ? "" : root
    }

    /** Whether a `static` function nested in this one can see a variable this one declares */
    _IsStatic(variable) => variable.kind == "static" || variable.kind == "function"

    Declare(name, kind, node := "") {
        variable := this._Variable(name)
        variable.kind := kind
        variable.declared := true
        variable.declaration := node
    }

    Write(name, node, value := "") {
        this._Variable(name).writes.Push({ node: node, value: value })
    }

    Read(name, node) {
        this._Variable(name).reads.Push(node)
    }

    _Variable(name) {
        if !this.variables.Has(name)
            this.variables[name] := Variable(name, this.isGlobal ? "global" : "local")
        return this.variables[name]
    }

    /** Variable names are case-insensitive */
    static _NameMap() {
        m := Map()
        m.CaseSense := false
        return m
    }
}

/**
 * Builds the scopes of a file during the linter's walk. Shared by every lint that asks for it, so the
 * bookkeeping is only done once per file.
 */
export class ScopeTracker {
    ; Nodes whose body is a function. Hotkey and hotstring bodies are functions too
    static FUNCTION_TYPES := [
        "function_declaration",
        "method_declaration",
        "function_expression",
        "fat_arrow_function",
        "getter",
        "setter",
        "hotkey",
        "hotstring"
    ]

    ; Nodes whose identifier children are never variable references: names of things that aren't
    ; variables, and names that _EnterFunction has already declared
    static NAME_PARENTS := Set(
        "function_declaration",
        "function_expression",
        "method_declaration",
        "property_declaration",
        "typed_property_declaration",
        "module_directive",
        "label",
        "goto_statement",
        "break_statement",
        "continue_statement",
        "param_sequence",
        "optional_param",
        "variadic_param",
        "byref_param",
        "dynamic_identifier"
    )

    /**
     * Every scope in the file, outer scopes before the ones nested in them. The global scope is first.
     * @type {Array<Scope>}
     */
    all := []

    _stack := []
    _byNode := Map()
    _callbacks := []

    /**
     * @param {Linter} linter the linter to listen to. Must not be sealed yet
     */
    __New(linter) {
        this.root := Scope("", "", "")
        this.all.Push(this.root)
        this._stack.Push(this.root)
        this._profiler := linter._profiler   ; times OnComplete callbacks under --profile

        linter.OnEnter(ScopeTracker.FUNCTION_TYPES, this._EnterFunction.Bind(this))
        linter.OnExit(ScopeTracker.FUNCTION_TYPES, (*) => this._stack.Pop())
        linter.OnEnter("identifier", this._SeeIdentifier.Bind(this))
        linter.OnEnter("variable_declaration", this._SeeDeclaration.Bind(this))
        linter.OnEnter(["dereference_operation", "dynamic_identifier"], this._SeeDynamicRef.Bind(this))
        linter.OnExit("source_file", this._Finish.Bind(this))
    }

    /**
     * The scope the walk is currently in. A listener on a node that opens a scope may see either
     * that scope or the enclosing one, depending on the order listeners were registered in.
     * @type {Scope}
     */
    current => this._stack[-1]

    /**
     * Register a callback to run once the whole file has been walked and every name is bound to its
     * variable. Lints that need complete information about a variable should do their work here.
     *
     * @param {Func(Linter, ScopeTracker) => Any} callback
     */
    OnComplete(callback) {
        this._callbacks.Push(this._profiler.Wrap(callback))
    }

    /**
     * The scope that `node` is in. Usable after the walk, unlike `current`.
     * @returns {Scope}
     */
    ScopeOf(node) {
        loop {
            node := node.Parent
            if node.IsNull
                return this.root
            if this._byNode.Has(key := ScopeTracker._Key(node))
                return this._byNode[key]
        }
    }

    ;@region Listeners

    _EnterFunction(_, node) {
        nodeType := node.type
        current := this.current

        if nodeType == "function_declaration" {
            name := node.GetChildByFieldName("name")
            current.Declare(name.text, "function", name)
        }

        ; Only functions nested in another function capture variables. A method doesn't see the
        ; variables of whatever its class is declared in.
        nested := !current.isGlobal
            && (nodeType == "function_declaration" || nodeType == "function_expression"
                || nodeType == "fat_arrow_function")
        inner := Scope(node, nested ? current : "", this.root)
        inner.isStatic := nested && nodeType == "function_declaration"
            && !node.GetChildByFieldName("scope").IsNull   ; `static Inner() {`

        for param in ScopeTracker._Params(node)
            inner.Declare(param.text, "param", param)
        switch nodeType {
            case "method_declaration", "getter":
                inner.Declare("this", "implicit")
            case "setter":
                inner.Declare("this", "implicit")
                inner.Declare("value", "implicit")
            case "hotkey", "hotstring":
                inner.Declare("ThisHotkey", "implicit")
        }

        this.all.Push(inner)
        this._stack.Push(inner)
        this._byNode[ScopeTracker._Key(node)] := inner
    }

    /** A bare `global` makes the function assume-global, a bare `static` assume-static */
    _SeeDeclaration(_, node) {
        if this.current.isGlobal || node.NamedChildCount != 1
            return
        switch ScopeTracker._Keyword(node), "off" {
            case "global": this.current.assumeGlobal := true
            case "static": this.current.assumeStatic := true
        }
    }

    /** `%name%` and `prefix%name%` can refer to any variable */
    _SeeDynamicRef(_, node) {
        parent := node.Parent
        switch parent.type {
            case "dynamic_identifier":
                return   ; part of a larger name, which is reported itself
            case "member_access":
                if ScopeTracker._IsField(parent, "member", node)
                    return   ; `obj.%name%` names a property, not a variable
            case "object_literal_member":
                if ScopeTracker._IsField(parent, "key", node)
                    return
        }

        scope := this.current
        while scope {
            scope.hasDynamicRefs := true
            scope := scope.outer
        }
        this.root.hasDynamicRefs := true
    }

    /** Work out what an identifier is doing from where it sits in its parent */
    _SeeIdentifier(_, node) {
        parent := node.Parent
        scope := this.current
        parentType := parent.type
        if ScopeTracker.NAME_PARENTS.Has(parentType)
            return

        switch parentType, "off" {
            case "property_declarator", "default_param":
                if ScopeTracker._IsField(parent, "name", node)
                    return

            case "fat_arrow_function":
                if !ScopeTracker._IsField(parent, "body", node)
                    return

            case "member_access":
                if ScopeTracker._IsField(parent, "member", node)
                    return

            case "object_literal_member":
                if ScopeTracker._IsField(parent, "key", node)
                    return

            case "class_declaration", "struct_declaration":
                if ScopeTracker._IsField(parent, "name", node) {
                    ; A nested class is a property of its outer class, not a variable
                    if parent.Parent.type != "class_body"
                        scope.Declare(node.text, "class", node)
                    return
                }

            case "import_directive":
                ; `#Import Mod` and `#Import "path" as Mod` bind the module itself
                if ScopeTracker._IsField(parent, "alias", node)
                    || (parent.GetChildByFieldName("alias").IsNull && TryGetChildOfType(parent, "export_name").IsNull)
                    scope.Declare(node.text, "import", node)
                return

            case "export_name":
                ; `{ Name }` binds Name, `{ Name as Alias }` binds only Alias
                if ScopeTracker._IsField(parent, "alias", node) || parent.GetChildByFieldName("alias").IsNull
                    scope.Declare(node.text, "import", node)
                return

            case "variable_declarator":
                if ScopeTracker._IsField(parent, "name", node) {
                    ScopeTracker._Declare(scope, parent, node)
                    return
                }

            case "assignment_operation":
                if target := ScopeTracker._AssignmentTarget(parent, node) {
                    if target.plain {
                        scope.Write(node.text, node, target.value)
                        return
                    }
                    scope.Write(node.text, node)   ; `.=`, `+=`, ... also read the old value
                }

            case "prefix_operation", "postfix_operation":
                if parent.GetChildByFieldName("operator").type ~= "^(\+\+|--)$"
                    scope.Write(node.text, node)

            case "varref_operation":
                scope.Write(node.text, node)   ; whoever gets the reference may assign through it

            case "for_statement":
                if parent.GetChildrenByFieldName("iterator").Any(iterator => iterator.Equals(node)) {
                    scope.Write(node.text, node)
                    return
                }

            case "catch_clause":
                if ScopeTracker._IsField(parent, "variable", node) {
                    scope.Write(node.text, node)
                    return
                }
        }

        scope.Read(node.text, node)
    }

    /** Bind every name to the variable it refers to, then fire callbacks */
    _Finish(linter, _) {
        for scope in this.all {
            ; Iterate a copy: deleting from a Map mid-enumeration skips the entry after the deleted one
            for name, variable in scope.variables.Clone() {
                owner := scope.OwnerOf(name)
                if owner == scope
                    continue

                target := owner._Variable(name)
                target.writes.Push(variable.writes*)
                target.reads.Push(variable.reads*)
                scope.variables.Delete(name)
            }
        }

        for callback in this._callbacks
            callback(linter, this)
    }

    ;@endregion
    ;@region Node helpers

    /** `static x := 1`, `local x`, `global x := 1` */
    static _Declare(scope, declarator, node) {
        name := node.text
        if !scope.isGlobal {
            keyword := this._Keyword(declarator.Parent)
            if keyword = "global"
                scope.globals[name] := true
            else
                scope.Declare(name, keyword, node)
        }

        value := declarator.GetChildByFieldName("value")
        if !value.IsNull
            scope.Write(name, node, value)
    }

    /**
     * If `node` is assigned to by `assignment`, describe the assignment.
     *
     * The grammar parses `a := b := 1` as `(a := b) := 1`, so both operands of an assignment that is
     * itself the left side of another are targets, and the value is the right side of the outermost one.
     *
     * @returns {Object | String} `{plain, value}`, where `plain` is whether every operator involved is
     *          `:=`; or an empty string if `node` is only read
     */
    static _AssignmentTarget(assignment, node) {
        chained := this._IsChained(assignment)
        if !chained && !this._IsField(assignment, "left", node)
            return ""

        plain := this._IsPlain(assignment)
        while chained {
            assignment := assignment.Parent
            plain := plain && this._IsPlain(assignment)
            chained := this._IsChained(assignment)
        }
        return { plain: plain, value: assignment.GetChildByFieldName("right") }
    }

    static _IsChained(assignment) {
        parent := assignment.Parent
        return parent.type == "assignment_operation" && this._IsField(parent, "left", assignment)
    }

    static _IsPlain(assignment) => Trim(assignment.GetChildByFieldName("operator").text, " `t`r`n") == ":="

    /** The scope keyword of a `variable_declaration`: "global", "local" or "static" */
    static _Keyword(declaration) => Trim(declaration.GetChildByFieldName("scope").text, " `t`r`n")

    /**
     * The identifiers naming the parameters of a function. A property's parameters (`Item[key]`)
     * belong to both its getter and its setter.
     * @returns {Array<Node>}
     */
    static _Params(node) {
        params := []
        if node.type ~= "^(getter|setter)$" {
            owner := node.Parent
            while !owner.IsNull && owner.type != "property_declaration"
                owner := owner.Parent
            if owner.IsNull
                return params
        } else {
            owner := node.GetChildByFieldName("head")
            if owner.IsNull
                return params
            if owner.type == "identifier"
                return [owner]   ; `x => x * 2`
        }

        sequence := TryGetChildOfType(owner, "param_sequence")
        if sequence.IsNull
            return params

        loop sequence.NamedChildCount {
            param := sequence.GetNamedChild(A_Index - 1)
            loop {
                switch param.type {
                    case "optional_param", "default_param", "variadic_param":
                        param := param.GetChildByFieldName("name")
                    case "byref_param":
                        param := param.GetChildByFieldName("param")
                        continue
                }
                break
            }
            if !param.IsNull && param.type == "identifier"   ; a bare `*` has no name
                params.Push(param)
        }
        return params
    }

    static _IsField(parent, field, node) => parent.GetChildByFieldName(field).Equals(node)

    /** Identifies a node within its tree */
    static _Key(node) => node.StartByte ":" node.EndByte ":" node.type

    ;@endregion
}
