#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "./Linter" { Linter }
#Import "./AutoHotkeyLang" { AutoHotkeyLang }
#Import "./LintRun" { LintRun }
#Import "./SourceText" { SourceText }
#Import "./Colors" { Red, Yellow }
#Import "./Fix" { FixToFixpoint }

/**
 * High-level orchestrator for a lint run.
 */
export class LintSession {
    /**
     * @param {Config} cfg the resolved config every file is linted with
     * @param {Array} formatters formatters to notify, see ConsoleFormatter
     * @param {File} stderr where to report a file that couldn't be written
     * @param {Boolean} fix write each file's fixes back to disk as it is linted
     * @param {Boolean} applySuggestions if true, also apply suggestions when fixing
     */
    __New(cfg, formatters, stderr, fix := false, applySuggestions := false) {
        this._cfg := cfg
        this._formatters := formatters
        this._stderr := stderr
        this._fix := fix
        this._applySuggestions := applySuggestions
        this.run := LintRun(cfg)
    }

    /**
     * Lint `root`. If a file, lints the file itself, if it's a directory, lints every
     * file in it or its subdirectories. Exclusions are not yet supported.
     *
     * @param {String} root absolute path of a file or directory
     */
    LintAll(root) {
        if InStr(FileGetAttrib(root), "D") {
            loop files root "\*.ahk", "r"
                this.LintOne(A_LoopFileFullPath)
        }
        else {
            this.LintOne(root)
        }
    }

    /**
     * Lint a file and record it in the lint run. When fixing, the file is fixed and
     * relinted in memory until nothing more applies, then written once; the recorded
     * result is what is left afterwards.
     *
     * @param {String} filepath absolute path of the file to lint
     * @returns {FileResult} the recorded result
     */
    LintOne(filepath) {
        for formatter in this._formatters
            formatter.OnFileStart(filepath)

        writeError := "", resolved := []
        try {
            source := FileRead(filepath, "RAW")
            diagnostics := this._Lint(source)

            if this._fix {
                fixed := FixToFixpoint(source, diagnostics, (src) => this._Lint(src),
                    this._applySuggestions)
                if !fixed.converged {
                    this._stderr.WriteLine(Yellow("ahklint: ") "fixes for " filepath
                        " did not settle after " fixed.passes " passes; some are left unapplied")
                }

                if fixed.passes > 0 {
                    try {
                        this._Write(filepath, fixed.source)
                        source := fixed.source, diagnostics := fixed.diagnostics
                        resolved := fixed.fixed
                    }
                    catch Error as err {
                        ; The file is unchanged, so report the findings it still has
                        this._stderr.WriteLine(Red("Error writing file ") filepath ": " err.message)
                        writeError := err
                    }
                }
            }

            result := this.run.AddFile(filepath, SourceText(source), diagnostics, resolved)
        } catch as e {
            result := this.run.AddError(filepath, e)
        }

        for formatter in this._formatters
            formatter.OnFile(result)

        ; Set once the formatters have shown the findings: the file linted fine, it
        ; just couldn't be written. Counted by run.ErrorCount.
        if writeError != ""
            result.error := writeError

        return result
    }

    /** Tell the formatters the run is complete. */
    Report() {
        for formatter in this._formatters
            formatter.OnFinish(this.run)
    }

    /**
     * @param {Buffer} source the source code to lint
     * @returns {Array<Diagnostic>} the findings
     */
    _Lint(source) => Linter(AutoHotkeyLang(), source, this._cfg).Run()

    /**
     * Replace the contents of `filepath` with `source`.
     */
    _Write(filepath, source) {
        ; The buffer already holds the file's own bytes (and BOM, if any), so
        ; open with a RAW encoding to keep FileOpen from adding a BOM
        f := FileOpen(filepath, "w", "UTF-8-RAW")
        f.RawWrite(source)
        f.Close()
    }

    /**
     * 2 if any file failed to lint, 1 if any finding fired, else 0. A finding that
     * was fixed is no longer on the run, so it doesn't count.
     */
    ExitCode {
        get {
            if (this.run.ErrorCount > 0)
                return 2
            return this.run.DiagnosticCount > 0 ? 1 : 0
        }
    }
}
