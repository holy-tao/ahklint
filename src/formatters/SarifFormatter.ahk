#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "../Docs" { DOCS_BASE, DocsUrl }
#Import "../Version" { AHKLINT_VERSION }
#Import "../lints/all.ahk" { LINT_DOCS }
#Import "cJson/JSON" { JSON }

SARIF_VERSION := "2.1.0"
SARIF_SCHEMA  := "https://json.schemastore.org/sarif-2.1.0.json"

/**
 * SARIF 2.1.0 output, for CI and code scanning (e.g. GitHub's upload-sarif).
 *
 * SARIF is one document describing the whole run, so this formatter does all
 * of its work in OnFinish. See ConsoleFormatter for the protocol.
 *
 * Columns are declared as `utf16CodeUnits`, which is exactly what
 * SourceText.Utf16Column counts. Paths under the working directory are written
 * relative to a `SRCROOT` base, which is what code scanning expects when the
 * linter runs from the checkout root.
 */
export class SarifFormatter {
    /**
     * @param {File} stream where to write the log
     * @param {Boolean} closeOnFinish close the stream after writing. On for a
     *        file the CLI opened, off for stdout.
     */
    __New(stream, closeOnFinish := false) {
        this._out := stream
        this._closeOnFinish := closeOnFinish
    }

    OnFileStart(*) => unset
    OnFile(*) => unset

    /**
     * Write the log for the finished run
     * @param {LintRun} run the run that just finished
     */
    OnFinish(run) {
        this._out.Write(JSON.Dump(CreateSarif(run, A_WorkingDir), true))
        if this._closeOnFinish
            this._out.Close()
    }
}

/**
 * Build the SARIF log for a run
 * @param {LintRun} run the run to report
 * @param {String} root directory that relative artifact URIs are resolved against
 * @returns {Map} a SARIF log, ready to serialize
 */
export CreateSarif(run, root) {
    rules := []
    ruleIndex := Map()   ; lint id -> 0-based index into rules
    for meta in run.EnabledLints {
        ruleIndex[meta.id] := rules.Length
        rules.Push(CreateRule(meta))
    }

    artifacts := []
    results := []
    notifications := []
    for i, fileResult in run.results {
        location := ArtifactLocation(fileResult.path, root)
        location["index"] := i - 1

        artifact := Map("location", ArtifactLocation(fileResult.path, root))
        if !fileResult.HasError
            artifact["length"] := fileResult.source.ByteCount
        artifacts.Push(artifact)

        if fileResult.HasError {
            formattedError := Format("failed to lint: {1}`r`n    Specifically: {2}`r`n`r`n{3}",
                fileResult.error.Message, fileResult.error.Extra, fileResult.error.Stack)
            notifications.Push(Map(
                "level", "error",
                "message", Map("text", "failed to lint: " formattedError),
                "locations", [Map("physicalLocation", Map("artifactLocation", location))]
            ))
            continue
        }

        for diag in fileResult.diagnostics
            results.Push(CreateResult(diag, fileResult.source, location, ruleIndex))
    }

    return Map(
        "version", SARIF_VERSION,
        "$schema", SARIF_SCHEMA,
        "runs", [Map(
            "tool", Map("driver", Map(
                "name", "ahklint",
                "version", AHKLINT_VERSION,
                "semanticVersion", AHKLINT_VERSION,
                "informationUri", DOCS_BASE,
                "rules", rules
            )),
            "columnKind", "utf16CodeUnits",
            "originalUriBaseIds", Map("SRCROOT", Map("uri", FileUri(root) "/")),
            "invocations", [Map(
                "executionSuccessful", run.ErrorCount == 0 ? JSON.True : JSON.False,
                "toolExecutionNotifications", notifications,
                "properties", Map("target", run.target)
            )],
            "artifacts", artifacts,
            "results", results
        )]
    )
}

/**
 * A SARIF reportingDescriptor for one lint
 * @param {Object} meta the lint's static meta
 * @returns {Map}
 */
CreateRule(meta) {
    url   := DocsUrl(meta.id)
    intro := LINT_DOCS.Get(meta.id, "")

    ; The first paragraph, unwrapped. GitHub requires full and help text.
    summary := Trim(StrReplace(StrSplit(intro, "`n`n")[1], "`n", " "))
    if summary == ""
        summary := meta.title

    return Map(
        "id", meta.id,
        "helpUri", url,
        ; TODO: strip Markdown formatting from the text nodes.
        "shortDescription", Map("text", meta.title),
        "fullDescription", Map("text", summary),
        "help", Map(
            "text", summary "`n`nSee " url,
            "markdown", (intro != "" ? intro : summary) "`n`n[Full documentation](" url ")"
        ),
        "defaultConfiguration", Map("level", Level(meta.severity)),
        "properties", Map(
            "tags", [meta.category],
            "precision", HasProp(meta, "precision") ? meta.precision : "high",
            "problem.severity", Level(meta.severity),
            "fixable", meta.fixable,
            "versions", meta.versions
        )
    )
}

/**
 * A SARIF result for one diagnostic
 * @param {Diagnostic} diag the finding
 * @param {SourceText} src the file it was found in
 * @param {Map} location the file's artifactLocation
 * @param {Map<String, Integer>} ruleIndex lint id -> index into the driver's rules
 * @returns {Map}
 */
CreateResult(diag, src, location, ruleIndex) {
    result := Map(
        "ruleId", diag.code,
        "level", Level(diag.severity),
        "message", Map("text", diag.message),
        "locations", [Map("physicalLocation", Map(
            "artifactLocation", location,
            "region", Region(src, diag.startByte, diag.endByte)
        ))]
    )
    if ruleIndex.Has(diag.code)
        result["ruleIndex"] := ruleIndex[diag.code]

    if diag.HasFix {
        replacements := []
        for fix in diag.fixes {
            replacements.Push(Map(
                "deletedRegion", Region(src, fix.startByte, fix.endByte),
                "insertedContent", Map("text", fix.newText)
            ))
        }
        result["fixes"] := [Map("artifactChanges", [Map(
            "artifactLocation", location,
            "replacements", replacements
        )])]
    }

    return result
}

/**
 * A SARIF region for a byte span. Carries both the text form (1-based lines,
 * 1-based UTF-16 columns, end column exclusive) and the byte form.
 * @param {SourceText} src the file
 * @param {Integer} startByte first byte of the span
 * @param {Integer} endByte byte after the span
 * @returns {Map}
 */
Region(src, startByte, endByte) => Map(
    "startLine",   src.RowAt(startByte) + 1,
    "startColumn", src.Utf16Column(startByte) + 1,
    "endLine",     src.RowAt(endByte) + 1,
    "endColumn",   src.Utf16Column(endByte) + 1,
    "byteOffset",  startByte,
    "byteLength",  endByte - startByte
)

/**
 * Map an ahklint severity to a SARIF level. "off" never reaches output: an
 * off lint is not enabled, so it neither runs nor appears in the rules.
 * @param {String} sev "warn" | "error"
 * @returns {String}
 */
Level(sev) {
    switch sev, "off" {
        case "warn":  return "warning"
        case "error": return "error"
        default: throw ValueError("No SARIF level for severity: " sev, -1)
    }
}

/**
 * An artifactLocation for a file: relative to SRCROOT when the file is under
 * `root`, an absolute file URI otherwise.
 * @param {String} path absolute path to the file
 * @param {String} root the SRCROOT directory
 * @returns {Map}
 */
ArtifactLocation(path, root) {
    prefix := RTrim(root, "\/") "\"
    if InStr(path, prefix) == 1   ; case-insensitive, like the file system
        return Map("uri", EncodeUriPath(StrReplace(SubStr(path, StrLen(prefix) + 1), "\", "/")),
            "uriBaseId", "SRCROOT")
    return Map("uri", FileUri(path))
}

/** An absolute `file:///` URI for a Windows path, without a trailing slash. */
FileUri(path) => "file:///" EncodeUriPath(StrReplace(RTrim(path, "\/"), "\", "/"))

/**
 * Percent-encode a path for use in a URI. Keeps `/` and `:` and the RFC 3986
 * unreserved characters, and encodes everything else as UTF-8 bytes.
 */
EncodeUriPath(path) {
    buf := Buffer(StrPut(path, "UTF-8"))
    size := StrPut(path, buf, "UTF-8") - 1   ; drop the null terminator
    out := ""
    loop size {
        b := NumGet(buf, A_Index - 1, "UChar")
        ch := Chr(b)
        if (b < 0x80 && RegExMatch(ch, "[A-Za-z0-9\-._~/:]"))
            out .= ch
        else
            out .= Format("%{:02X}", b)
    }
    return out
}
