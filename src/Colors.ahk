#Requires AutoHotkey v2.1-alpha.30

#Import "utils/Console" { Console }

; default to false so that errors during startup don't mangle console outputs
; main() sets to true / false after parsing args and environment variables
_enabled := false

_Colored(code, text) {
    if !_enabled
        return text
    return Console.Escape "[" String(code) "m" text . Console.Escape "[0m"
}

/**
 * Enable or disable ANSI colors.
 * @param {Any} enabled whether to enable colors
 */
export SetEnabled(enabled) {
    global _enabled := !!enabled
}

/**
 * Whether ANSI escape sequences should be written at all.
 * @returns {Boolean}
 */
export IsEnabled() {
    return _enabled
}

export global red := _Colored.Bind(31)
export global green := _Colored.Bind(32)
export global yellow := _Colored.Bind(33)
export global blue := _Colored.Bind(34)
export global magenta := _Colored.Bind(35)
export global cyan := _Colored.Bind(36)
export global gray := _Colored.Bind(90)
