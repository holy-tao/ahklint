#Requires AutoHotkey v2.1-alpha.30

/**
 * Enforce consistent quote styles for string literals.
 */
class QuoteStyle {
    static meta => {
        id:          "quote-style",
        title:       "Quote Style",
        category:    "style",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/v2/Language.htm#strings"
        ],
        options: {
            style: {
                type:        "string",
                default:     "double",
                values:      ["double", "single"],
                description: "The quote character string literals should use."
            },
            avoidEscape: {
                type:        "boolean",
                default:     true,
                description: "Allow the other quote character when the string contains the "
                    . "preferred one, so it doesn't need to be escaped."
            }
        }
    }

    __New(linter) {
        opts := linter.Options(QuoteStyle.meta)
        this.quote       := opts.style == "double" ? '"' : "'"
        this.avoidEscape := opts.avoidEscape
        this.message     := "Strings should use " opts.style " quotes."

        linter.OnEnter(["string_literal", "multiline_string_literal"], this.SeeStringLiteral.Bind(this))
    }

    SeeStringLiteral(linter, node) {
        text := node.Text
        if SubStr(text, 1, 1) == this.quote
            return

        if this.avoidEscape  && node.type == "string_literal" ; continuation strings don't need quotes to be escaped
            && QuoteStyle.HasUnescaped(SubStr(text, 2, -1), this.quote) 
        {
            return
        }

        linter.Report(QuoteStyle.meta, node, this.message)
    }

    /**
     * Does a string literal's body contain `char` without a preceding escape? Such
     * a character would need escaping if the literal were requoted with `char`.
     */
    static HasUnescaped(body, char) {
        i := 1
        while i <= StrLen(body) {
            c := SubStr(body, i, 1)
            if c == "``"
                i++                 ; skip the escaped character
            else if c == char
                return true
            i++
        }
        return false
    }
}
