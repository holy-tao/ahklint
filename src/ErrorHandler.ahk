#Requires AutoHotkey v2.1-alpha.30

#Import "utils/Console" { Console }
#Import "Colors" { Red, Magenta, Gray, Cyan }

; CLI shim to handle uncaught errors and pretty-print them to the console

/**
 * Pretty-print an error
 * @param err
 * @returns {unset?}
 */
PrintError(err) {
    static STACK_PAT := "S)^(?<path>.*)\s\((?<line>\d+)\)\s:\s\[(?<function>\w*)\]\s(?<code>.*)$"

    msg := Red(A_IsCompiled ? "ahklint" : Type(err)) ": " err.Message "`n"
    if err.Extra != "" {
        msg .= "    Specifically: " err.Extra "`n"
    }

    msg .= "`n"
    loop parse err.Stack, "`n" {
        if RegExMatch(A_LoopField, STACK_PAT, &match := "") {
            msg .= Format("{1} ({2}) : [{3}] {4}`n",
                Cyan(match.path), Gray(match.line), Magenta(match.function), match.code)
        } else {
            msg .= A_LoopField "`n"
        }
    }

    Console.err.WriteLine(msg)
}

OnError((err, *) => (PrintError(err), ExitApp(2)))
