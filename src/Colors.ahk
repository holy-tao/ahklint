#Requires AutoHotkey v2.1-alpha.30

#Import "utils/Console" { Console }

; default to false so that errors during startup don't mangle console outputs
; main() sets to true / false after parsing args and environment variables
_enabled := false

_Colored(code, text) {
    if !_enabled
        return text
    return Console.Escape "[" String(code) "m" text Console.Escape "[0m"
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

export global Red := _Colored.Bind(31)
export global Green := _Colored.Bind(32)
export global Yellow := _Colored.Bind(33)
export global Blue := _Colored.Bind(34)
export global Magenta := _Colored.Bind(35)
export global Cyan := _Colored.Bind(36)
export global Gray := _Colored.Bind(90)
