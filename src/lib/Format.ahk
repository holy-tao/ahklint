/**
 * Shared helpers for lints that reason about format strings
 */

/**
 * Represents a format string placeholder
 */
class Placeholder {
    __New(text, rawIndex, hasColon, format) {
        this.text := text
        this.index := 0 ; effective index, accounting for {} sequences. 0 if the placeholder is invalid
        this.rawIndex := rawIndex ; the actual text in the index part (if any)
        this.format := format
        this.error := Placeholder.GetError(rawIndex, hasColon, format) ; "" if the placeholder is valid
    }

    /**
     * Whether Format will substitute this placeholder. Invalid placeholders are copied into the result
     * as-is and don't consume an input value.
     */
    IsValid => this.error == ""

    /**
     * Get a string representation of the placeholder optionally normalizing it. Normalizing
     * will always include the index and `:`, even if it wasn't present in the original.
     *
     * @param {Boolean} norm whether to normalize the output
     * @returns {String}
     */
    ToString(norm := false) => norm ? this.Normalized() : this.text

    Normalized() => "{" this.index . (this.format ? ":" this.format : "") "}"

    /**
     * Validate a placeholder's parts and return an error message if it's invalid.
     *
     * @param {String} rawIndex the text of the index part, if any
     * @param {Boolean} hasColon whether the index was followed by a `:`
     * @param {String} format the text of the format specifier, if any
     * @returns {String} "" if the placeholder is valid, an error message if it isn't
     */
    static GetError(rawIndex, hasColon, format) {
        if rawIndex != "" {
            if !IsDigit(rawIndex)
                return "index must not have a sign"
            if Integer(rawIndex) < 1
                return "index must be positive"
        }

        if format != "" && !hasColon
            return rawIndex != "" ? "format must be preceded by ':'" : "index must be an integer"

        return Placeholder.GetFormatError(format)
    }

    /**
     * Validate a format specifier (the text after the `:`), which takes the form
     * `Flags Width .Precision ULT Type`, each part optional.
     *
     * @param {String} fmt the format specifier
     * @returns {String} "" if the specifier is valid, an error message if it isn't
     */
    static GetFormatError(fmt) {
        ; Always matches; anything the grammar doesn't account for lands in `type`
        RegExMatch(fmt, "^(?<flags>[-+0 #]*)(?<width>\d*)(?<prec>\.\d*)?(?<ult>[ULTlt]*)(?<type>.*)$", &m)

        if RegExMatch(m.type, "\s")
            return "whitespace is not permitted except as a flag"
        if StrLen(m.type) > 1
            return "unexpected '" m.type "'"
        if m.type != "" && !InStr("diuxXofeEgGaApscC", m.type, true)
            return "unknown type '" m.type "'"
        if StrLen(m.ult) > 1
            return "only one case transformation (U, L, T) is allowed"
        if m.ult != "" && m.type != "" && m.type != "s"
            return "case transformation '" m.ult "' is only valid with the 's' type"

        return ""
    }
}

/**
 * Collect all format placeholders in a Format string, returning an array of `{ text, index, format }` objects
 * for each placeholder. The placeholders appear in the array in the order in which they appear in the
 * string, which isn't necessarily the order of the arguments they consume; you have `{1}` as the third
 * item.
 *
 * Invalid placeholders are included (check `IsValid`), but have an index of 0 and don't advance the
 * sequence, since Format doesn't substitute them. The `{{}` and `{}}` escapes are not placeholders.
 *
 * @param {String} fmtString the first argument to Format
 * @returns {Array<Placeholder>} all of the placeholders in the format string, in the order in which they
 *      occur in the source text
 */
CollectPlaceholders(fmtString) {
    ; Per docs: "Omit the index to use the next input value in the sequence
    ; (even if it has been used earlier in the string)"
    lastIndex := 0, placeholders := []

    ; Escapes are matched first so that e.g. the `{}` in `{{}` isn't mistaken for a placeholder
    match := "", pos := 1
    while RegExMatch(fmtString, "{(?:{}|}}|(?<idx>[+-]?\d+)?(?<colon>:)?(?<fmt>[^{}]*)})", &match, pos) {
        pos := match.Pos + match.Len
        if match[0] == "{{}" || match[0] == "{}}"
            continue

        p := Placeholder(match[0], match.idx, match.colon != "", match.fmt)
        if p.IsValid
            p.index := match.idx != "" ? lastIndex := Integer(match.idx) : ++lastIndex

        placeholders.Push(p)
    }

    return placeholders
}
