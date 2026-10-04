#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "utils\Glob" { FileSystemMatcher as GlobMatcher }

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
            ; static assumes there's only ever one LintSession but avoids recompiling globs
            static matcher := GlobMatcher(this._cfg.includes, this._cfg.excludes)
            for match in matcher.Matches(root)
                this.LintOne(match)
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

        result := this._Check(filepath, , &writeError)

        for formatter in this._formatters
            formatter.OnFile(result)

        ; Set once the formatters have shown the findings: the file linted fine, it
        ; just couldn't be written. Counted by run.ErrorCount.
        if writeError != ""
            result.error := writeError

        return result
    }

    /**
     * Lint a file again if it has changed since its result was recorded, without
     * telling the formatters; see Replay. A file that has gone is dropped from the
     * run.
     *
     * The comparison is against the bytes the result describes, which under `--fix`
     * are the ones this session wrote. So the change notification for our own
     * write is a no-op, and fixing can't feed itself.
     *
     * @param {String} filepath absolute path of the file to lint
     * @returns {Boolean} true if the run changed
     */
    Refresh(filepath) {
        if !FileExist(filepath)
            return this.run.Remove(filepath)

        result := this._Check(filepath, true, &writeError)
        if result == ""
            return false
        if writeError != ""
            result.error := writeError
        return true
    }

    /**
     * Drop the result of every file that no longer exists.
     * @returns {Boolean} true if the run changed
     */
    Prune() {
        gone := this.run.results
            .Map(result => result.path)
            .Filter(path => !FileExist(path))

        for path in gone
            this.run.Remove(path)
        return gone.Length > 0
    }

    /**
     * Show the formatters the run as it stands, as if it had just been linted.
     * In a run of several files the clean ones are left out, so what is on screen
     * is what needs attention.
     */
    Replay() {
        quiet := this.run.FileCount > 1
        for result in this.run.results {
            if quiet && !result.HasError && result.diagnostics.Length == 0 && result.fixed.Length == 0
                continue
            for formatter in this._formatters {
                formatter.OnFileStart(result.path)
                formatter.OnFile(result)
            }
        }
        this.Report()
    }

    /**
     * Forget which findings were fixed, so a Replay doesn't announce fixes made
     * for an earlier change.
     */
    ClearFixed() {
        for result in this.run.results
            result.fixed := []
    }

    /**
     * Lint a file, fix it if asked to, and record the result on the run.
     *
     * @param {String} filepath absolute path of the file to lint
     * @param {Boolean} onlyIfChanged do nothing if the file still holds the bytes
     *        its recorded result describes
     * @param {VarRef} writeError set to the error if the fixed file couldn't be
     *        written, else "". The result then describes the file as it was.
     * @returns {FileResult | String} the recorded result, or "" if unchanged
     */
    _Check(filepath, onlyIfChanged := false, &writeError := "") {
        writeError := "", resolved := []
        try {
            source := FileRead(filepath, "RAW")
            if onlyIfChanged {
                previous := this.run.Find(filepath)
                if previous && !previous.HasError && previous.source.Matches(source)
                    return ""
            }

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
                        this._stderr.WriteLine(Red("Error writing file ") . filepath ": " err.message)
                        writeError := err
                    }
                }
            }

            return this.run.AddFile(filepath, SourceText(source), diagnostics, resolved)
        } catch as e {
            return this.run.AddError(filepath, e)
        }
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
    exitCode {
        get {
            if this.run.ErrorCount > 0
                return 2
            return this.run.DiagnosticCount > 0 ? 1 : 0
        }
    }
}
