#Requires AutoHotkey v2.1-alpha.30 64-bit

/** The outcome for one file: its findings, or the error that prevented them. */
export class FileResult {
    /**
     * @param {String} path absolute path to the linted file
     * @param {SourceText} source the file's bytes, or unset when it never parsed
     * @param {Array<Diagnostic>} diagnostics the findings, empty when clean
     * @param {Error} error optional - the failure that stopped this file
     */
    __New(path, source := "", diagnostics := [], error := "") {
        this.path        := path
        this.source      := source
        this.diagnostics := diagnostics
        this.error       := error
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
    }

    /** Record a file that linted successfully. Returns the new FileResult. */
    AddFile(path, source, diagnostics) {
        result := FileResult(path, source, diagnostics)
        this.results.Push(result)
        return result
    }

    /** Record a file that threw. The run continues; the exit code reflects it. */
    AddError(path, error) {
        result := FileResult(path, , , error)
        this.results.Push(result)
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
