#Requires AutoHotkey v2.1-alpha.30 64-bit

/**
 * The bytes of one linted file, indexed by line.
 *
 * The linter reads sources as RAW buffers and tree-sitter reports spans as byte
 * offsets, so everything downstream needs a way back from a byte offset to
 * something a human or an editor understands.
 *
 * There are two column units we care about:
 *   - *bytes*, used by tree-sitter and `Diagnostic`.
 *   - *UTF-16 code units*, used by LSPs and SARIF.
 */
export class SourceText {
    /**
     * @param {Buffer} buffer the file contents, as read with FileRead(.., "RAW")
     */
    __New(buffer) {
        this._buf    := buffer
        this._lines  := Map()   ; row -> decoded line, filled on demand
        this._starts := [0]     ; 1-based: _starts[row + 1] is row's first byte

        ptr := buffer.Ptr, size := buffer.Size
        i := 0
        while (i < size) {
            if NumGet(ptr, i, "UChar") == 0x0A
                this._starts.Push(i + 1)
            i++
        }
    }

    /** Number of lines. A trailing newline yields a final empty line. */
    LineCount => this._starts.Length

    /** Total size in bytes. */
    ByteCount => this._buf.Size

    /**
     * The whole source, decoded. Cached, since SARIF embeds it per artifact.
     * @returns {String}
     */
    Text {
        get {
            if !this.HasProp("_text")
                this._text := StrGet(this._buf.Ptr, this._buf.Size, "UTF-8")
            return this._text
        }
    }

    /**
     * One line, decoded, without its terminator.
     * @param {Integer} row 0-indexed line number
     * @returns {String} "" for a row past the end
     */
    Line(row) {
        if this._lines.Has(row)
            return this._lines[row]
        if (row < 0 || row >= this._starts.Length)
            return ""

        start := this._starts[row + 1]
        end   := (row + 2 <= this._starts.Length) ? this._starts[row + 2] : this._buf.Size

        ; Drop the terminator: \n, and the \r before it on CRLF input.
        if (end > start && NumGet(this._buf.Ptr, end - 1, "UChar") == 0x0A)
            end--
        if (end > start && NumGet(this._buf.Ptr, end - 1, "UChar") == 0x0D)
            end--

        line := (end > start) ? StrGet(this._buf.Ptr + start, end - start, "UTF-8") : ""
        this._lines[row] := line
        return line
    }

    /**
     * The 0-indexed row a byte offset falls on. Binary search over the line
     * starts, so this is cheap enough to call per diagnostic.
     */
    RowAt(byteOffset) {
        lo := 1, hi := this._starts.Length
        while (lo < hi) {
            mid := (lo + hi + 1) // 2
            if (this._starts[mid] <= byteOffset)
                lo := mid
            else
                hi := mid - 1
        }
        return lo - 1
    }

    /**
     * The 0-indexed UTF-16 column a byte offset falls on - the unit LSP counts
     * and the one to render with.
     */
    Utf16Column(byteOffset) {
        row   := this.RowAt(byteOffset)
        start := this._starts[row + 1]
        if (byteOffset <= start)
            return 0
        return StrLen(StrGet(this._buf.Ptr + start, byteOffset - start, "UTF-8"))
    }
}
