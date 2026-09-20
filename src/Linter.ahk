#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import treesitter { Parser }
#Import "treesitter/util" { Visitor }

#Import "extensions/MapExtensions"
#Import "extensions/ArrayExtensions"
#Import "collections/Typed/TypedArray" { TypedArray }

#Import "./Diagnostic.ahk" { Diagnostic }
#Import "./Config.ahk" { Config }
#Import "./lints/all.ahk" { ALL_LINTS }

export global DEFAULT_TARGET := "2.0.26"

/**
 * The lint engine. Owns the parse tree, instantiates the enabled lints, walks
 * the tree once, and collects diagnostics.
 *
 * It doubles as the *context* handed to each lint: lints register listeners via
 * OnEnter/OnExit (inherited from Visitor) and emit findings via Report. No I/O
 * lives here - the caller (ahklint.ahk) reads files and prints results.
 */
export class Linter extends Visitor {

    _sealed := false

    /**
     * Ignore directives in this linter's source, mapped from line number
     * to an array of the ignored lints' ids
     * TODO: introduce a meta-lint for unused ignore directives
     * 
     * @type {Map<Integer, Array<String>>}
     */
    ignores := Map()

    /**
     * @param {Language} lang the tree-sitter language to parse with
     * @param {Buffer} source the file contents (read as "RAW")
     * @param {Config} configMap resolved config; defaults to the recommended preset
     *        at DEFAULT_TARGET when omitted (used by tests and ad-hoc callers)
     */
    __New(lang, source, cfg?) {
        this._language := lang
        this._parser := Parser(lang)
        this._source := source
        this._config := cfg ?? Config.Default(ALL_LINTS, DEFAULT_TARGET)
        this.ahkVersion := this._config.target
        this._tree := this._parser.Parse(source)   ; keep alive: nodes read from it
        this._diagnostics := A_IsCompiled ? [] : TypedArray(Diagnostic)
        this.lints := []
        this.ignores := this.FindIgnoreDirectives()

        super.__New(this._tree.Root)                 ; Visitor walks from the root

        ; Construction phase: each lint registers its listeners. Afterwards the
        ; context is sealed so listeners can't change mid-walk
        for cls in ALL_LINTS {
            meta := cls.meta
            ; undocumented config option to run everything
            if !A_IsCompiled && !HasProp(this._config, "UNIT_TEST_RUN") {
               if !VerCompare(this._config.target, meta.versions)
                   continue
            }

            if this._config.SeverityFor(meta.id) != "off"
                this.lints.Push(cls(this))
        }
        this._sealed := true
    }

    /**
     * Find and parse all ignore directives in this linter's source.
     * @returns {Map<Integer, Array<String>>} Map of line numbers to ignored lint ids
     */
    FindIgnoreDirectives() {
        cursor := this._tree.Query("(directive_comment) @directive")
        ignores := Map()

        while match := cursor.NextMatch() {
            node := match.captures[1].node
            name := node.GetChildByFieldName("directive").text
            if InStr(name, "ahklint") != 1
                continue ; not our directive
            
            ignoredIds := StrSplit(node.GetChildByFieldName("arguments").text, " ", " `r`n`t")
                .Filter(str => str)

            switch name, "off" {
                case "ahklint-ignore": ignores[node.startPoint.row] := ignoredIds
                case "ahklint-ignore-next-line": ignores[node.startPoint.row + 1] := ignoredIds
            }
        }

        return ignores
    }

    /** Walk the tree and return the collected diagnostics. */
    Run() {
        this.Visit()
        return this._diagnostics
    }

    /**
     * Whether this lint is ignored
     * @param {Object} meta the reporting lint's static meta 
     * @param {Node} node tree-sitter node that was linted 
     * @returns {Integer} 1 if the lint is ignored, 0 if not
     */
    IsIgnored(meta, node) {
        return this.ignores.Get(node.startPoint.row, [])
            .Any(id => id = meta.id)
    }

    /**
     * Called by lints to emit a finding. Pulls id/severity/docs from the lint's
     * meta
     *
     * @param {Object} meta the reporting lint's static meta
     * @param {Node} node the node to anchor the finding to
     * @param {String} message the message to show
     * @param {Array<Fix>} fixes optional edits that resolve the finding, each
     *        `{ startByte, endByte, newText }` - see Diagnostic
     */
    Report(meta, node, message, fixes?) {
        if this.IsIgnored(meta, node)
            return

        severity := this._config.SeverityFor(meta.id)   ; config wins over meta.severity
        this._diagnostics.Push(Diagnostic(meta, node, message, severity, fixes?))
    }

    /**
     * Called by lints (usually in __New) to read their configured options.
     *
     * @param {Object} meta the calling lint's static meta
     * @returns {Object} option name -> value
     */
    Options(meta) => this._config.OptionsFor(meta.id)

    OnEnter(nodeType, callback, addRemove := 1) {
        this._AssertUnsealed()
        if nodeType is Array {
            for t in nodeType {
                super.OnEnter(t, callback, addRemove)
            }
        } else {
            super.OnEnter(nodeType, callback, addRemove)
        }
    }

    OnExit(nodeType, callback, addRemove := 1) {
        this._AssertUnsealed()
        if nodeType is Array {
            for t in nodeType {
                super.OnExit(t, callback, addRemove)
            }
        } else {
            super.OnExit(nodeType, callback, addRemove)
        }
    }

    _AssertUnsealed() {
        if this._sealed
            throw Error("Lints may only register listeners during construction", -2)
    }
}
