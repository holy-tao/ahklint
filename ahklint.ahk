#Requires AutoHotkey v2.1-alpha.30 64-bit
#ErrorStdOut 'UTF-8'

#DllLoad "./bin/tree-sitter.dll"
#DllLoad "./bin/tree-sitter-autohotkey.dll"

#Import "./Linter.ahk" { Linter }
#Import "./AutoHotkeyLang.ahk" { AutoHotkeyLang }

;@Ahk2Exe-ConsoleApp

main()

/**
 * CLI entry point: `ahklint <file.ahk>`
 * Parses one file, prints diagnostics, exits non-zero if any were found.
 */
main() {
    stdout := FileOpen("*", "w")
    stderr := FileOpen("**", "w")

    if !A_Args.Length {
        ; TODO if A_Args[1] is a directory, scan it and all subdirectories for .ahk files
        if !A_IsCompiled {
            ; Allow usage from e.g. VSCode without wrangling the command line
            A_Args.Push(FileSelect("1", A_WorkingDir, "Select a file to lint", "AutoHotkey scripts (*.ahk)"))
        } else {
            stderr.WriteLine("usage: ahklint <file.ahk>")
            ExitApp(2)
        }
    }

    filepath := A_Args[1]
    if !FileExist(filepath) {
        stderr.WriteLine("ahklint: no such file: " filepath)
        ExitApp(2)
    }

    ; TODO load config and pass to Linter

    source := FileRead(filepath, "RAW")
    diagnostics := Linter(AutoHotkeyLang(), source).Run()

    for diag in diagnostics
        stdout.WriteLine(diag.Format(filepath))

    stdout.WriteLine(Format("`n{1} problem(s)", diagnostics.Length))
    ExitApp(diagnostics.Length ? 1 : 0)
}
