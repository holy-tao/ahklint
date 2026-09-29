/**
 * Shared helpers for lints that reason about format strings
 */

/**
 * Represents a format string placeholder
 */
class Placeholder {
    __New(text, index, format) {
        this.text := text
        this.index := index
        this.format := format
    }

    /**
     * Get a string representation of the placeholder optionally normalizing it. Normalizing
     * will always include the index and `:`, even if it wasn't present in the original.
     *
     * @param {Boolean} norm whether to normalize the output
     * @returns {String} 
     */
    ToString(norm := false) => norm ? this.Normalized() : this.text

    Normalized() => "{" this.index . (this.format ? ":" this.format : "") "}"
}

/**
 * Collect all format placeholders in a Format string, returning an array of `{ text, index, format }` objects
 * for each placeholder. The placeholders appear in the array in the order in which they appear in the
 * string, which isn't necessarily the order of the arguments they consume; you have `{1}` as the third
 * item.
 *
 * @param {String} fmtString the first argument to Format
 * @returns {Array<Placeholder>} all of the placeholders in the format string, in the order in which they
 *      occur in the source text
 */
CollectPlaceholders(fmtString) {
    ; Per docs: "Omit the index to use the next input value in the sequence
    ; (even if it has been used earlier in the string)"
    lastIndex := 0, placeholders := []

    match := "", pos := 1
    while RegExMatch(fmtString, "{(?<idx>\d+)?:?(?<fmt>[^{}]*)}", &match, pos) {
        placeholders.Push(Placeholder(
            match[0],
            IsInteger(match.idx) ? lastIndex := Integer(match.idx) : ++lastIndex,
            match.fmt
        ))

        pos := match.Pos + match.Len
    }

    return placeholders
}
