#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "./Linter" { Linter }
#Import "./AutoHotkeyLang" { AutoHotkeyLang }
#Import "./LintRun" { LintRun }
#Import "./SourceText" { SourceText }
#Import "./Colors" { Red }
#Import "./Fix" { ApplyFixes }

/**
 * High-level orchestrator for a lint run.
 */
export class LintSession {
    /**
     * @param {Config} cfg the resolved config every file is linted with
     * @param {Array} formatters formatters to notify, see ConsoleFormatter
     * @param {File} stderr where to report a file that couldn't be written
     */
    __New(cfg, formatters, stderr) {
        this._cfg := cfg
        this._formatters := formatters
        this._stderr := stderr
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
     * Lint a file and record it in the lint run.
     *
     * @param {String} filepath absolute path of the file to lint
     * @returns {FileResult} the recorded result
     */
    LintOne(filepath) {
        for formatter in this._formatters
            formatter.OnFileStart(filepath)

        try {
            source := FileRead(filepath, "RAW")
            diagnostics := Linter(AutoHotkeyLang(), source, this._cfg).Run()
            result := this.run.AddFile(filepath, SourceText(source), diagnostics)
        } catch as e {
            result := this.run.AddError(filepath, e)
        }

        for formatter in this._formatters
            formatter.OnFile(result)

        return result
    }

    /** Tell the formatters the run is complete. */
    Report() {
        for formatter in this._formatters
            formatter.OnFinish(this.run)
    }

    /**
     * Write the fixes for every file in the run back to disk. A file with nothing
     * to fix is left untouched.
     *
     * @param {Boolean} includeSuggestions if true, also apply suggestions
     */
    WriteFixes(includeSuggestions := false) {
        for result in this.run.results {
            fixed := ApplyFixes(result, includeSuggestions)
            if !(fixed is Buffer)
                continue
            try {
                ; The buffer already holds the file's own bytes (and BOM, if any), so
                ; open with a RAW encoding to keep FileOpen from adding a BOM
                f := FileOpen(result.path, "w", "UTF-8-RAW")
                f.RawWrite(fixed)
                f.Close()
            }
            catch Error as err {
                this._stderr.WriteLine(Red("Error writing file ") result.path ": " err.message)
                result.error := err  ; counted by run.ErrorCount
            }
        }
    }

    /** 2 if any file failed to lint, 1 if any finding fired, else 0. */
    ExitCode {
        get {
            if (this.run.ErrorCount > 0)
                return 2
            return this.run.DiagnosticCount > 0 ? 1 : 0
        }
    }
}
