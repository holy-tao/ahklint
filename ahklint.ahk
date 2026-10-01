#Requires AutoHotkey v2.1-alpha.30 64-bit
#ErrorStdOut 'UTF-8'

#DllLoad "./bin/tree-sitter.dll"
#DllLoad "./bin/tree-sitter-autohotkey.dll"

#Import "./src/CLI.ahk" { ParseArgs, ShowVersion, ShowHelp }
#Import "./src/Config.ahk" { LoadConfig }
#Import "./src/LintSession.ahk" { LintSession }
#Import "./src/FileWatcher.ahk" { FileWatcher }
#Import "./src/formatters/ConsoleFormatter.ahk" { ConsoleFormatter }
#Import "./src/formatters/SarifFormatter.ahk" { SarifFormatter }
#Import "./src/Colors" { SetEnabled as SetANSIColorsEnabled, Red }

#Import "utils/Console" { Console }
;@Ahk2Exe-ConsoleApp

Console.Attach()

main()

/**
 * CLI entry point: `ahklint [--config <path>] [--target <ver>] [--sarif <path>] <file.ahk>`
 *
 * Resolves the arguments, config and formatters, then hands the linting itself
 * to a LintSession.
 *
 * Exit code: 2 if any file failed to lint, 1 if any finding fired, else 0. With
 * `--watch` the process keeps running until it is interrupted.
 */
main() {
    args := ParseArgs(A_Args)
    SetANSIColorsEnabled(!args.noColor)

    ; Done here so that help and version respects NO_COLOR
    if args.showVersion {
        ShowVersion()
    } else if args.showHelp {
        ShowHelp()
        ExitApp(0)
    }

    filepath := args.file
    if (filepath == "")
        filepath := A_WorkingDir

    if !FileExist(filepath) {
        Console.Err.WriteLine("ahklint: no such file: " filepath)
        ExitApp(2)
    }

    cfg := LoadConfig(args, filepath, Console.Err)

    isDir := !!InStr(FileGetAttrib(filepath), "D")

    ; The console streams as it goes; whole-run formats buffer on `run` instead.
    ; `--sarif -` puts SARIF on stdout, so the console output is dropped rather
    ; than mixed into the JSON.
    formatters := []
    if (args.sarifPath != "-")
        formatters.Push(ConsoleFormatter(Console.Out, isDir))
    if (args.sarifPath != "")
        formatters.Push(OpenSarifFormatter(args.sarifPath, Console.Err))

    session := LintSession(cfg, formatters, Console.Err, args.fix, args.applySuggestions)
    root := GetFullPathName(filepath)
    session.LintAll(root)
    session.Report()

    if args.watch {
        ; Static, so the watcher outlives this call
        static watcher
        watcher := FileWatcher(session, root, Console.Out)
        Persistent()
        return
    }

    ExitApp(session.ExitCode)
}

/**
 * Create the SARIF formatter for `--sarif <path>`. The file is opened before
 * linting starts, so an unwritable path fails fast instead of after the run.
 *
 * @param {String} path where to write, or "-" for stdout
 * @param {File} stderr where to report a failure
 * @returns {SarifFormatter}
 */
OpenSarifFormatter(path, stderr) {
    if (path == "-")
        return SarifFormatter(Console.Out)

    try {
        SplitPath(GetFullPathName(path), , &dir)
        if !DirExist(dir)
            DirCreate(dir)
        stream := FileOpen(path, "w", "UTF-8-RAW")   ; SARIF is UTF-8 with no BOM
    }
    if !IsSet(stream) || !stream {
        stderr.WriteLine(Red("ahklint: ") "cannot write " path)
        ExitApp(2)
    }
    return SarifFormatter(stream, true)
}

GetFullPathName(path) {
    cc := DllCall("GetFullPathName", "str", path, UInt32, 0, IntPtr, 0, IntPtr, 0, UInt32)
    buf := Buffer(cc*2)
    DllCall("GetFullPathName", "str", path, UInt32, cc, IntPtr, buf.ptr, IntPtr, 0)
    return StrGet(buf)
}

