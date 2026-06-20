#Requires AutoHotkey v2.1-alpha.30 64-bit
#ErrorStdOut 'UTF-8'

#DllLoad "./bin/tree-sitter.dll"
#DllLoad "./bin/tree-sitter-autohotkey.dll"

#Import "./Linter.ahk" { Linter, DEFAULT_TARGET }
#Import "./AutoHotkeyLang.ahk" { AutoHotkeyLang }
#Import "./Config.ahk" { Config }
#Import "./lints/all.ahk" { ALL_LINTS }

;@Ahk2Exe-ConsoleApp

stdout := FileOpen("*", "w")
stderr := FileOpen("**", "w")

main()

/**
 * CLI entry point: `ahklint [--config <path>] [--target <ver>] <file.ahk>`
 * Parses one file, prints diagnostics, exits non-zero if any were found.
 */
main() {

    args := ParseArgs(A_Args, stderr)   ; { file, configPath, target }

    filepath := args.file
    if (filepath == "") 
        filepath := A_WorkingDir

    if !FileExist(filepath) {
        stderr.WriteLine("ahklint: no such file: " filepath)
        ExitApp(2)
    }

    cfg := LoadConfig(args, filepath, stderr)

    diagnostics := 0

    if InStr(FileGetAttrib(filepath), "D") {
        ; Directory - lint all files in it and subdirectories
        loop files GetFullPathName(filepath) "\*.ahk", "r" {
            stdout.WriteLine(Format("Linting {1}...", A_LoopFilePath))
            diagnostics += LintFile(A_LoopFileFullPath, cfg)
        }
    }
    else {
        diagnostics := LintFile(GetFullPathName(filepath), cfg)
    }

    ExitApp(diagnostics > 0 ? 1 : 0)
}

/**
 * Lints the given file
 * 
 * @param {String} filepath path of the file to lint 
 * @returns {Integer} the number of diagnostics emitted
 */
LintFile(filepath, cfg) {
    source := FileRead(filepath, "RAW")
    diagnostics := Linter(AutoHotkeyLang(), source, cfg).Run()

    for diag in diagnostics
        stdout.WriteLine(diag.Format(filepath))

    stdout.WriteLine(Format("{1} problem(s)", diagnostics.Length))
    return diagnostics.Length
}

GetFullPathName(path) {
    cc := DllCall("GetFullPathName", "str", path, UInt32, 0, IntPtr, 0, IntPtr, 0, UInt32)
    buf := Buffer(cc*2)
    DllCall("GetFullPathName", "str", path, UInt32, cc, IntPtr, buf.ptr, IntPtr, 0)
    return StrGet(buf)
}

/**
 * Parse argv into { file, configPath, target }. Accepts `--config <path>` and
 * `--target <ver>` anywhere; the first positional argument is the file. Unknown
 * `--options` and missing flag values are hard errors (usage + exit 2).
 */
ParseArgs(argv, stderr) {
    out := { file: "", configPath: "", target: "" }
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
                stderr.WriteLine("ahklint: no target version set; assuming " DEFAULT_TARGET
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
    stderr.WriteLine("ahklint: " message)
    stderr.WriteLine("usage: ahklint [--config <path>] [--target <ver>] <file.ahk>")
    ExitApp(2)
}
