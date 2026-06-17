#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "lib/tree-sitter" { Parser }
#Import "lib/tree-sitter/src/util/Visitor.ahk" as Visitor

#Import "./Diagnostic.ahk" { Diagnostic }
#Import "./lints/all.ahk" { ALL_LINTS }

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
     * @param {Language} lang the tree-sitter language to parse with
     * @param {Buffer} source the file contents (read as "RAW")
     */
    __New(lang, source) {
        this._parser := Parser(lang)
        this._source := source
        this._tree   := this._parser.Parse(source)   ; keep alive: nodes read from it
        this._diagnostics := []
        this._lints := []

        super.__New(this._tree.Root)                 ; Visitor walks from the root

        ; Construction phase: each lint registers its listeners. Afterwards the
        ; context is sealed so listeners can't change mid-walk
        for cls in ALL_LINTS {
            ; TODO: skip lints by meta.versions / config severity here
            this._lints.Push(cls(this))
        }
        this._sealed := true
    }

    /** Walk the tree and return the collected diagnostics. */
    Run() {
        this.Visit()
        return this._diagnostics
    }

    /**
     * Called by lints to emit a finding. Pulls id/severity/docs from the lint's
     * meta
     *
     * @param {Object} meta the reporting lint's static meta
     * @param {Node} node the node to anchor the finding to
     * @param {String} message the message to show
     */
    Report(meta, node, message) {
        this._diagnostics.Push(Diagnostic(meta, node, message))
    }

    OnEnter(nodeType, callback, addRemove := 1) {
        this._AssertUnsealed()
        super.OnEnter(nodeType, callback, addRemove)
    }

    OnExit(nodeType, callback, addRemove := 1) {
        this._AssertUnsealed()
        super.OnExit(nodeType, callback, addRemove)
    }

    _AssertUnsealed() {
        if this._sealed
            throw Error("Lints may only register listeners during construction", -2)
    }
}
