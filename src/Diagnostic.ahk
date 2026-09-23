#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "./Docs.ahk" { DocsUrl }
#Import "collections/Typed/TypedArray" { TypedArray }

/**
 * A single lint finding. Field names mirror an LSP Diagnostic closely enough
 * that an editor integration can map onto it later (see DESIGN.md "Report shape").
 */
export class Diagnostic {
    /**
     * @param {Object} meta the reporting lint's static `meta`
     * @param {Node} node the tree-sitter node the finding is anchored to
     * @param {String} message the human-readable message
     * @param {String} severity resolved severity; defaults to meta.severity when
     *        a caller (or test) doesn't pass a config-resolved value
     * @param {Array<Fix>} fixes optional edits that resolve the finding, each
     *        `{ startByte, endByte, newText }`.
     */
    __New(meta, node, message, severity?, fixes := []) {
        this.code     := meta.id          ; lint id           -> LSP `code`
        this.severity := IsSet(severity) ? severity : meta.severity  ; config wins (Linter.Report)
        this.docs     := DocsUrl(meta.id) ; doc URL (derived)  -> LSP `codeDescription.href`
        this.message  := message
        ; Runtime type checking only when not compiled
        this.fixes    := A_IsCompiled
            ? (fixes is Array ? fixes : [fixes])
            : TypedArray(Fix, (fixes is Array ? fixes : [fixes])*)
        this.fixable  := meta.fixable

        ; Keep both span forms: byte offsets for slicing source, row/col for editors.
        ; Note that `start.column` / `end.column` are BYTE columns - render through
        ; SourceText.Utf16Column instead of using them directly.
        this.startByte := node.StartByte
        this.endByte   := node.EndByte
        this.start     := node.StartPoint ; Point {row, column}, 0-indexed
        this.end       := node.EndPoint
    }

    /** Whether this finding carries edits that would resolve it. */
    HasFix => this.fixes.Length > 0
}

/**
 * An edit fixing a diagnostic.
 */
class Fix {
    __New(startByte, endByte, newText) {
        ;@ahk2exe-ignorebegin
        if endByte < startByte
            throw ValueError(Format("EndByte must be >= startByte (got {1} , {2})", startByte, endByte))
        ;@ahk2exe-ignoreend

        this.startByte := Integer(startByte)
        this.endByte := Integer(endByte)
        this.newText := String(newText)
    }

    /**
     * Construct a fix that replaces the given tree-sitter node with the given text.
     * Use the standard constructor if the byte range to be replaced spans multiple nodes.
     * 
     * @param {Node} node tree-sitter node to be replaced 
     * @param {String} newText the replacement text
     * @returns {Fix} the new fix 
     */
    static To(node, newText) => Fix(node.StartByte, node.EndByte, newText)
}