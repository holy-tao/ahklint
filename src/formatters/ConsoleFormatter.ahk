#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "../Colors.ahk" { Red, Yellow, Cyan, Magenta }

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
            return
        }

        for diag in result.diagnostics
            this._out.WriteLine(this.FormatDiagnostic(diag, result))

        this._out.WriteLine(Format("{1} problem(s)", result.diagnostics.Length))
    }

    OnFinish(run) {
        ; A single-file run already printed its count; don't repeat it.
        if (run.FileCount > 1) {
            this._out.WriteLine(Format("`n{1} problem(s) in {2} file(s)",
                run.DiagnosticCount, run.FileCount))
        }

        ; A failed file produced no findings, so say so - otherwise a run that
        ; silently skipped half its input looks clean.
        if (run.ErrorCount > 0)
            this._out.WriteLine(Red(Format("{1} file(s) failed to lint", run.ErrorCount)))
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
        str .= "Line |`n"

        line := StrReplace(src.Line(row), "`t", " ")

        ; Only the first line of a multi-line span is shown: underline from the
        ; start column to the end of that line and note where the span ends.
        multiline := diag.end.row > row
        endCol := Max(multiline ? StrLen(line) : src.Utf16Column(diag.endByte), startCol)

        lineStart := SubStr(line, 1, startCol)
        errPart   := SubStr(line, startCol + 1, endCol - startCol)
        lineEnd   := SubStr(line, endCol + 1)

        str .= Format("{1:4} | {2}`n", row + 1, lineStart color(errPart) lineEnd)
        str .= Format("     | {1}{2}{3}`n",
            this._StrRepeat(" ", startCol),
            color(this._StrRepeat("~", endCol - startCol)),
            multiline ? Format(" (continues to line {1})", diag.end.row + 1) : "")

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
