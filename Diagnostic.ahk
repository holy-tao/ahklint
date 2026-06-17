#Requires AutoHotkey v2.1-alpha.30 64-bit

/**
 * A single lint finding. Field names mirror an LSP Diagnostic closely enough
 * that an editor integration can map onto it later (see DESIGN.md "Report shape").
 */
export class Diagnostic {
    /**
     * @param {Object} meta the reporting lint's static `meta`
     * @param {Node} node the tree-sitter node the finding is anchored to
     * @param {String} message the human-readable message
     */
    __New(meta, node, message) {
        this.code     := meta.id          ; lint id           -> LSP `code`
        this.severity := meta.severity    ; TODO: config overrides this default
        this.docs     := meta.docs        ; doc URL           -> LSP `codeDescription.href`
        this.message  := message

        ; Keep both span forms: byte offsets for slicing source, row/col for editors.
        this.startByte := node.StartByte
        this.endByte   := node.EndByte
        this.start     := node.StartPoint ; Point {row, column}, 0-indexed
        this.end       := node.EndPoint
    }

    /**
     * Human-readable output for the console
     */
    Format(file) {
        str := Format("{1} [{2}] {3}:`n", file, this.code, this.severity)
        str .= "Line |`n"
        str .= Format("{1:4} | {2}`n", this.start.row + 1, this._ReadLine(file, this.start.row + 1))
        str .= Format("     | {1}{2}`n",
            this._StrRepeat(" ", this.start.column), 
            this._StrRepeat("^", this.end.column - this.start.column))
        str .= Format("     | {1}`n", this.message)
        str .= Format("     | See: {1}`n", this.docs)
        return str
    }

    _ReadLine(file, line) {
        file := FileOpen(file, "r")
        loop (line - 1)
            file.ReadLine()
        return file.ReadLine()
    }

    _StrRepeat(str, amt) {
        out := "", VarSetStrCapacity(&out, amt + 1)
        loop amt 
            out .= str
        return out 
    }
}
