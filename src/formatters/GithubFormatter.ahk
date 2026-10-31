#Requires AutoHotkey v2.1-alpha.30 64-bit

/**
 * Escape a workflow command's message. GitHub percent-encodes rather than using
 * backslash escapes; this matches `escapeData` in @actions/core.
 * @param {String} text the text to escape
 * @returns {String} the escaped text
 */
EscapeData(text) {
    text := StrReplace(text, "%", "%25")
    text := StrReplace(text, "`r", "%0D")
    text := StrReplace(text, "`n", "%0A")
    return text
}

/**
 * Escape a workflow command property (`file=`, `title=`). Properties are
 * separated by `,` and ended by `:`, so both are encoded too; this matches
 * `escapeProperty` in @actions/core.
 * @param {String} text the text to escape
 * @returns {String} the escaped text
 */
EscapeProperty(text) {
    text := EscapeData(text)
    text := StrReplace(text, ":", "%3A")
    text := StrReplace(text, ",", "%2C")
    return text
}

/**
 * The path to annotate a file with. GitHub attaches an annotation by its path
 * relative to the repository, so a file under GITHUB_WORKSPACE is written
 * relative to it; anything else is left as it is.
 * @param {String} path absolute path to the file
 * @returns {String}
 */
AnnotationPath(path) {
    static workspace := EnvGet("GITHUB_WORKSPACE")
    if workspace != "" {
        prefix := StrReplace(RTrim(workspace, "\/"), "/", "\") "\"
        if InStr(path, prefix) == 1   ; case-insensitive, like the file system
            path := SubStr(path, StrLen(prefix) + 1)
    }
    return StrReplace(path, "\", "/")
}

FormatError(file, err) {
    text := Format("{1}: {2}", Type(err), err.Message)
    if err.extra
        text .= " (Specifically: " err.extra ")"
    text .= "`n" err.Stack
    return Format("::error file={1},title={2}::{3}",
        EscapeProperty(AnnotationPath(file)), EscapeProperty("Failed to lint file"), EscapeData(text))
}

FormatDiagnostic(diag, result) {
    src := result.source
    startLine := src.RowAt(diag.startByte) + 1
    endLine   := src.RowAt(diag.endByte) + 1

    attrs := Format("file={1},line={2},endLine={3}",
        EscapeProperty(AnnotationPath(result.path)), startLine, endLine)

    ; GitHub only accepts columns on an annotation that starts and ends on one line
    if startLine == endLine {
        attrs .= Format(",col={1},endColumn={2}",
            src.Utf16Column(diag.startByte) + 1, src.Utf16Column(diag.endByte) + 1)
    }
    attrs .= ",title=" EscapeProperty(diag.code)

    return Format("::{1} {2}::{3}",
        diag.severity = "warn" ? "warning" : "error",
        attrs,
        EscapeData(diag.message "`nSee: " diag.docs))
}

/**
 * Formats diagnostics as `::error` and `::warning` lines for GitHub actions
 * to consume.
 *
 * See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
 */
export class GithubFormatter {

    __New(stream) {
        this._out := stream
    }

    OnFileStart(*) {
        ; do nothing
    }

    OnFile(result) {
        if result.HasError {
            this._out.WriteLine(FormatError(result.path, result.error))
            return
        }

        for diag in result.diagnostics
            this._out.WriteLine(FormatDiagnostic(diag, result))
    }

    OnFinish(*) {
        ; do nothing
    }
}
