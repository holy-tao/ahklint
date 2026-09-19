#Requires AutoHotkey v2.1-alpha.30

#Import "utils/Console" { Console }

_Colored(code, text) {
    ; TODO - respect NO_COLOR
    return Console.Escape "[" String(code) "m" text Console.Escape "[0m"
}

export global Red := _Colored.Bind(31)
export global Green := _Colored.Bind(32)
export global Yellow := _Colored.Bind(33)
export global Blue := _Colored.Bind(34)
export global Magenta := _Colored.Bind(35)
export global Cyan := _Colored.Bind(36)