#Requires AutoHotkey v2.1-alpha.30 64-bit
#ErrorStdOut 'UTF-8'

#DllLoad "./bin/tree-sitter.dll"
#DllLoad "./bin/tree-sitter-autohotkey.dll"

#Import "./src/Linter.ahk" { Linter, DEFAULT_TARGET }
#Import "./src/AutoHotkeyLang.ahk" { AutoHotkeyLang }
#Import "./src/Config.ahk" { Config }
#Import "./src/LintRun.ahk" { LintRun }
#Import "./src/SourceText.ahk" { SourceText }
#Import "./src/Version.ahk" { AHKLINT_VERSION }
#Import "./src/formatters/ConsoleFormatter.ahk" { ConsoleFormatter }
#Import "./src/formatters/SarifFormatter.ahk" { SarifFormatter }
#Import "./src/lints/all.ahk" { ALL_LINTS }
#Import "./src/Colors" { SetEnabled as SetANSIColorsEnabled, Red, Yellow }

#Import "utils/Console" { Console }

;@Ahk2Exe-ConsoleApp

Console.Attach()

main()

/**
 * CLI entry point: `ahklint [--config <path>] [--target <ver>] [--sarif <path>] <file.ahk>`
 *
 * Collects every file's findings into one LintRun and hands them to the
 * formatters. The run is built even for a single file, because a format like
 * SARIF describes the whole invocation rather than one file at a time.
 *
 * Exit code: 2 if any file failed to lint, 1 if any finding fired, else 0.
 */
main() {
    args := ParseArgs(A_Args, Console.Err)   ; { file, configPath, target, ... }
    SetANSIColorsEnabled(!args.noColor)

    if args.showVersion {
        Console.Out.WriteLine("ahklint " AHKLINT_VERSION)
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
    run := LintRun(cfg)

    isDir := !!InStr(FileGetAttrib(filepath), "D")

    ; The console streams as it goes; whole-run formats buffer on `run` instead.
    ; `--sarif -` puts SARIF on stdout, so the console output is dropped rather
    ; than mixed into the JSON.
    formatters := []
    if (args.sarifPath != "-")
        formatters.Push(ConsoleFormatter(Console.Out, isDir))
    if (args.sarifPath != "")
        formatters.Push(OpenSarifFormatter(args.sarifPath, Console.Err))

    if isDir {
        ; Directory - lint all files in it and subdirectories
        loop files GetFullPathName(filepath) "\*.ahk", "r"
            LintFile(A_LoopFileFullPath, cfg, run, formatters)
    }
    else {
        LintFile(GetFullPathName(filepath), cfg, run, formatters)
    }

    for formatter in formatters
        formatter.OnFinish(run)

    if (run.ErrorCount > 0)
        ExitApp(2)
    ExitApp(run.DiagnosticCount > 0 ? 1 : 0)
}

/**
 * Lint one file and record it on the run. A file that throws is recorded as an
 * error rather than aborting the walk, so one unparseable file in a directory
 * doesn't lose the results of every other file.
 *
 * @param {String} filepath path of the file to lint
 * @param {Config} cfg the resolved config
 * @param {LintRun} run the run to record the result on
 * @param {Array} formatters formatters to notify
 * @returns {FileResult} the recorded result
 */
LintFile(filepath, cfg, run, formatters) {
    for formatter in formatters
        formatter.OnFileStart(filepath)

    try {
        source := FileRead(filepath, "RAW")
        diagnostics := Linter(AutoHotkeyLang(), source, cfg).Run()
        result := run.AddFile(filepath, SourceText(source), diagnostics)
    } catch as e {
        result := run.AddError(filepath, e)
    }

    for formatter in formatters
        formatter.OnFile(result)

    return result
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

/**
 * Parse argv into { file, configPath, target, noColor, showVersion, sarifPath }. Accepts
 * `--config <path>` and `--target <ver>` anywhere; the first positional argument
 * is the file. Unknown `--options` and missing flag values are hard errors
 * (usage + exit 2).
 */
ParseArgs(argv, stderr) {
    out := { file: "", configPath: "", target: "", noColor : !!EnvGet("NO_COLOR"),
             showVersion: false, sarifPath: "" }
    i := 1
    while (i <= argv.Length) {
        arg := argv[i]
        switch arg {
            case "--config":
                if (i == argv.Length)
                    Die(stderr, "--config requires a path")
                out.configPath := argv[++i]
            case "--target":
                if (i == argv.Length)
                    Die(stderr, "--target requires a version")
                out.target := argv[++i]
            case "--no-color":
                out.noColor := true
            case "--version":
                out.showVersion := true
            case "--sarif":
                if (i == argv.Length)
                    Die(stderr, "--sarif requires a path")
                out.sarifPath := argv[++i]
            default:
                if (SubStr(arg, 1, 2) == "--")
                    Die(stderr, "unknown option: " arg)
                if (out.file == "")
                    out.file := arg
        }
        i++
    }
    return out
}

/**
 * Resolve the target version and load/validate config. Target precedence:
 * --target flag > config "target" > DEFAULT_TARGET (with a one-line notice).
 * Config is discovered by walking up from the linted file unless --config is
 * given. Any config error (bad JSON, unknown lint id/preset) exits 2.
 * 
 * @returns {Config} the loaded config
 */
LoadConfig(args, filepath, stderr) {
    try {
        configPath := args.configPath
        if (configPath == "") {
            SplitPath(filepath, , &fileDir)
            configPath := Config.Discover(fileDir != "" ? fileDir : A_WorkingDir)
        } else if !FileExist(configPath) {
            throw ValueError("no such config file: " configPath)
        }

        parsed := configPath != "" ? Config.ParseFile(configPath) : Map()

        target := args.target
        if (target == "") {
            if parsed.Has("target") {
                target := parsed["target"]
            } else {
                target := DEFAULT_TARGET
                stderr.WriteLine(Yellow("ahklint: ") "no target version set; assuming " DEFAULT_TARGET
                    . ". Set --target or a `"target`" in config to silence this.")
            }
        }

        return Config(parsed, ALL_LINTS, target)
    } catch as e {
        stderr.WriteLine("ahklint: " e.message)
        ExitApp(2)
    }
}

Die(stderr, message) {
    stderr.WriteLine(Red("ahklint: ") message)
    stderr.WriteLine("usage: ahklint [--config <path>] [--target <ver>] [--sarif <path>] [--no-color] <file.ahk>")
    stderr.WriteLine("       ahklint --version")
    ExitApp(2)
}
