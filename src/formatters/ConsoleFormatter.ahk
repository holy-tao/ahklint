#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "../Colors.ahk" { Red, Yellow, Cyan, Magenta, Gray }

/*
 * ## The formatter protocol
 *
 * A formatter owns its destination stream and is driven by the CLI as the run
 * proceeds. Every formatter implements these four; a whole-run format such as
 * SARIF leaves the first three empty and does all of its work in OnFinish:
 *
 *     __New(stream)          take the File to write to
 *     OnFileStart(path)      about to lint this file
 *     OnFile(result)         this FileResult is complete
 *     OnFinish(run)          the LintRun is complete
 *
 * Streaming matters here: a directory walk should print each file's findings as
 * it goes rather than going silent until the end. Formats that must emit one
 * document buffer everything on the LintRun instead, which is why the run keeps
 * every result rather than a running count.
 */ 

/**
 * Human-readable console output.
 */
export class ConsoleFormatter {
    /**
     * @param {File} stream where to write (normally Console.Out)
     * @param {Boolean} showFileHeaders print a "Linting <path>..." line per file.
     *        On for a directory walk, off for a single file, where the path is
     *        already on every diagnostic.
     */
    __New(stream, showFileHeaders := false) {
        this._out := stream
        this._showFileHeaders := showFileHeaders
    }

    OnFileStart(path) {
        if this._showFileHeaders
            this._out.WriteLine(Format("Linting {1}...", path))
    }

    OnFile(result) {
        if result.HasError {
            this._out.WriteLine(Format("{1} {2}: {3}",
                Red("failed to lint"), result.path, result.error.Message))
            if result.error.extra {
                this._out.WriteLine("    Specifically: " result.error.extra "`n")
            }
            this._out.WriteLine(result.error.Stack)
            return
        }

        for diag in result.diagnostics
            this._out.WriteLine(this.FormatDiagnostic(diag, result))

        this._out.WriteLine(Format("{1} problem(s)", result.diagnostics.Length)
            . this.FormatFixed(result.fixed))
    }

    OnFinish(run) {
        ; A single-file run already printed its count; don't repeat it.
        if run.FileCount > 1 {
            this._out.WriteLine(Format("`n{1} problem(s) in {2} file(s)",
                run.DiagnosticCount, run.FileCount)
                . (run.FixedCount > 0 ? Format(", {1} fixed", run.FixedCount) : ""))
        }

        ; A failed file produced no findings, so say so - otherwise a run that
        ; silently skipped half its input looks clean.
        if run.ErrorCount > 0
            this._out.WriteLine(Red(Format("{1} file(s) failed to lint", run.ErrorCount)))
    }

    /**
     * The findings `--fix` resolved in one file, as a count per lint to go after
     * the problem count: `, 3 fixed (2 quote-style, 1 concat-style)`.
     *
     * They aren't shown as excerpts like the remaining findings: the code they
     * pointed at has been rewritten, so there is no line left to underline.
     *
     * @param {Array<Diagnostic>} fixed the resolved findings
     * @returns {String} empty when nothing was fixed
     */
    FormatFixed(fixed) {
        if fixed.Length == 0
            return ""

        counts := Map()
        for diag in fixed
            counts[diag.code] := counts.Get(diag.code, 0) + 1

        breakdown := ""
        for code, count in counts
            breakdown .= (breakdown == "" ? "" : ", ") . count " " Magenta(code)

        return Format(", {1} fixed ({2})", fixed.Length, breakdown)
    }

    /**
     * One finding, as a source excerpt with the span underlined.
     *
     * Columns come from SourceText.Utf16Column rather than from the diagnostic's
     * byte columns, so the caret lands under the span on lines containing
     * non-ASCII text.
     *
     * @param {Diagnostic} diag the finding
     * @param {FileResult} result the file it was found in
     * @returns {String}
     */
    FormatDiagnostic(diag, result) {
        color := diag.severity = "warn" ? Yellow : Red
        src   := result.source
        row   := diag.start.row

        startCol := src.Utf16Column(diag.startByte)

        str := Format("{1}:{2}:{3} [{4}] {5}:`n", result.path,
            row + 1, startCol + 1, Magenta(diag.code), color(diag.severity))
        str .= Gray("Line") " |`n"

        line := StrReplace(src.Line(row), "`t", " ")

        ; Only the first line of a multi-line span is shown: underline from the
        ; start column to the end of that line and note where the span ends.
        multiline := diag.end.row > row
        endCol := Max(multiline ? StrLen(line) : src.Utf16Column(diag.endByte), startCol)

        lineStart := SubStr(line, 1, startCol)
        errPart   := SubStr(line, startCol + 1, endCol - startCol)
        lineEnd   := SubStr(line, endCol + 1)

        loop Max(0, 4 - StrLen(String(row + 1)))
            str .= " "
        str .= Gray(row + 1)
        str .= " | " lineStart . color(errPart) . lineEnd "`n"

        str .= Format("     | {1}{2}{3}`n",
            this._StrRepeat(" ", startCol),
            color(this._StrRepeat("~", endCol - startCol)),
            multiline ? Gray(Format(" (continues to line {1})", diag.end.row + 1)) : "")

        str .= Format("     | {1}`n", diag.message)
        str .= Format("     | See: {1}`n", Cyan(diag.docs))
        return str
    }

    _StrRepeat(str, amt) {
        out := "", VarSetStrCapacity(&out, Max(amt, 0) + 1)
        loop amt
            out .= str
        return out
    }
}
