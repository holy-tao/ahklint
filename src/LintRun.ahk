#Requires AutoHotkey v2.1-alpha.30 64-bit

/** The outcome for one file: its findings, or the error that prevented them. */
export class FileResult {
    /**
     * @param {String} path absolute path to the linted file
     * @param {SourceText} source the file's bytes, or unset when it never parsed
     * @param {Array<Diagnostic>} diagnostics the findings, empty when clean
     * @param {Error} error optional - the failure that stopped this file
     * @param {Array<Diagnostic>} fixed the findings `--fix` resolved, which are no
     *        longer in `diagnostics`. Their spans predate the fix, so they can't be
     *        resolved against `source`.
     */
    __New(path, source := "", diagnostics := [], error := "", fixed := []) {
        this.path        := path
        this.source      := source
        this.diagnostics := diagnostics
        this.error       := error
        this.fixed       := fixed
    }

    HasError => this.error != ""
}

/**
 * Represents the result of an invocation of the linter. Consumed by
 * formatters.
 */
export class LintRun {
    /**
     * @param {Config} config the resolved config every file in this run was linted with
     */
    __New(config) {
        this._config := config
        this.target  := config.target
        this.results := []

        ; path -> FileResult, so a relinted file replaces its result. Windows paths
        ; are case-insensitive.
        this._byPath := Map()
        this._byPath.CaseSense := "Off"
    }

    /**
     * Record a file that linted successfully, replacing any earlier result for the
     * same path. Returns the new FileResult.
     */
    AddFile(path, source, diagnostics, fixed := []) =>
        this._Record(FileResult(path, source, diagnostics, , fixed))

    /**
     * Record a file that threw, replacing any earlier result for the same path. The
     * run continues; the exit code reflects it.
     */
    AddError(path, error) => this._Record(FileResult(path, , , error))

    /**
     * @param {String} path absolute path of a file
     * @returns {FileResult | String} the result recorded for `path`, or "" if none
     */
    Find(path) => this._byPath.Get(path, "")

    /**
     * Drop the result recorded for `path`, if any.
     * @returns {Boolean} true if there was one
     */
    Remove(path) {
        if !this._byPath.Has(path)
            return false
        this.results.RemoveAt(this._IndexOf(this._byPath.Delete(path)))
        return true
    }

    _IndexOf(result) {
        for candidate in this.results
            if candidate == result
                return A_Index
    }

    _Record(result) {
        ; A file is only linted again under --watch, a file or two at a time, so
        ; replacing can afford to scan for the old result's slot
        if (previous := this._byPath.Get(result.path, ""))
            this.results[this._IndexOf(previous)] := result
        else
            this.results.Push(result)

        this._byPath[result.path] := result
        return result
    }

    /** Total findings across every file. */
    DiagnosticCount {
        get {
            total := 0
            for result in this.results
                total += result.diagnostics.Length
            return total
        }
    }

    /** Total findings resolved by `--fix` across every file. */
    FixedCount {
        get {
            total := 0
            for result in this.results
                total += result.fixed.Length
            return total
        }
    }

    /** How many files failed to lint. */
    ErrorCount {
        get {
            total := 0
            for result in this.results
                total += result.HasError ? 1 : 0
            return total
        }
    }

    FileCount => this.results.Length

    /**
     * The metas of the lints that were enabled for this run - what a SARIF
     * driver lists as its rules, and what a language server announces.
     * @returns {Array<Object>}
     */
    EnabledLints => this._config.EnabledMetas()
}
