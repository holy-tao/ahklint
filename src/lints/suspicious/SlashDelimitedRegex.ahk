#Requires AutoHotkey v2.1-alpha.30

#Import "../../Diagnostic" { Fix }

/**
 * Looks for string literals that appear to be slash-delimited regexes like `/pattern/opts`, as you would
 * get from copying a regex from tools like regex101.com. AHK uses a slightly different format, so these are
 * *probably* mistakes.
 *
 * Does *not* filter by function type, as it's common for regex patterns to be stored in their own variables.
 */
class SlashDelimitedRegex {
    static meta => {
        id:          "slash-delimited-regex",
        title:       "Slash Delimited Regex",
        category:    "suspicious",
        tags:        ["regex"],
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "suggestion",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/alpha/misc/RegEx-QuickRef.htm"]
    }

    __New(linter) {
        linter.OnEnter("string_literal", this.CheckString.Bind(this))
    }

    CheckString(linter, node) {
        static PATTERN := "S)(?<!\\)\/(?<pattern>.*)(?<!\\)\/(?<modifiers>.*)?"
        if !RegExMatch(SubStr(node.text, 2, -1), PATTERN, &match := "")
            return

        replacement := match.modifiers
            ? match.modifiers ")" match.pattern
            : match.pattern

        message := "This regex appears to use the slash-delimited form. AHK uses another format: ``" replacement "``"

        ; + 1 / - 1 so we don't touch quotes
        patch := Fix(node.startByte + 1, node.endByte - 1, replacement)
        linter.Report(SlashDelimitedRegex.meta, node, message, patch)
    }
}
