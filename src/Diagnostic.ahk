#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "./Docs.ahk" { DocsUrl }
#Import Colors { Red, Yellow, Cyan, Magenta }

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
     */
    __New(meta, node, message, severity?) {
        this.code     := meta.id          ; lint id           -> LSP `code`
        this.severity := IsSet(severity) ? severity : meta.severity  ; config wins (Linter.Report)
        this.docs     := DocsUrl(meta.id) ; doc URL (derived)  -> LSP `codeDescription.href`
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
        color := this.severity = "warn" ? Yellow : Red

        str := Format("{1}:{2}:{3} [{4}] {5}:`n", file, 
            this.start.row + 1, this.start.column + 1, Magenta(this.code), color(this.severity))
        str .= "Line |`n"

        line := this._ReadLine(file, this.start.row + 1)

        ; Only the first line of a multi-line span is shown: underline from the
        ; start column to the end of that line and note where the span ends.
        multiline := this.end.row > this.start.row
        endCol := Max(multiline ? StrLen(line) : this.end.column, this.start.column)

        lineStart := SubStr(line, 1, this.start.column)
        errPart := SubStr(line, this.start.column + 1, endCol - this.start.column)
        lineEnd := SubStr(line, endCol + 1)

        coloredLine := lineStart color(errPart) lineEnd

        str .= Format("{1:4} | {2}`n", this.start.row + 1, coloredLine)
        str .= Format("     | {1}{2}{3}`n",
            this._StrRepeat(" ", this.start.column),
            color(this._StrRepeat("~", endCol - this.start.column)),
            multiline ? Format(" (continues to line {1})", this.end.row + 1) : "")

        str .= Format("     | {1}`n", this.message)
        str .= Format("     | See: {1}`n", Cyan(this.docs))
        return str
    }

    _ReadLine(file, line) {
        file := FileOpen(file, "r")
        loop (line - 1)
            file.ReadLine()
        return StrReplace(file.ReadLine(), "`t", " ")
    }

    _StrRepeat(str, amt) {
        out := "", VarSetStrCapacity(&out, Max(amt, 0) + 1)
        loop amt 
            out .= str
        return out 
    }
}
