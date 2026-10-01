#Requires AutoHotkey v2.1-alpha.30

#Import "Colors" { Red, Cyan, Magenta, Yellow, Green, Gray }
#Import "utils\Console" { Console }
#Import "./lib/Util" { StrJoin }
#Import "Version" { AHKLINT_VERSION }

/**
 * CLI options with their defaults. Mostly exists to get editor hints.
 */
class CliArgs {
    file := ""
    configPath := ""
    target := ""
    noColor := !!EnvGet("NO_COLOR")
    showVersion := false
    showHelp := false
    sarifPath := ""
    fix := false
    applySuggestions := false
    watch := false
}

Die(message) {
    ShowHelp()
    Console.err.WriteLine(Red("ahklint: ") . message)
    ExitApp(2)
}

/**
 * Shows the CLI help text. Does not exit the program.
 */
ShowHelp() {
    static LEFT_COLUMN_WIDTH := 20

    Arg(arg, desc, default := "") {
        str := "  " Magenta(arg)
        padding := LEFT_COLUMN_WIDTH - StrLen(arg)
        str .= Format("{:" Max(0, padding) "}{}", "", desc)

        if default
            str .= Gray(" [default: " default "]")

        Console.out.WriteLine(str)
    }

    Opt(flags, desc, default := "") {
        str := "  " StrJoin(", ", flags.Map(f => Cyan(f))*)
    
        padding := LEFT_COLUMN_WIDTH - (flags.SumBy(StrLen) + (2 * (flags.Length - 1)))
        if padding < 0 {
            str .= "`n"
            padding := LEFT_COLUMN_WIDTH + 2
        }
        str .= Format("{:" padding "}{}", "", desc)

        if default
            str .= Gray(" [default: " default "]")

        Console.out.WriteLine(str)
    }

    Console.Out.WriteLine(Format("{1}: an AutoHotkey v2/v2.1 linter.", Green(A_ScriptName)))
    Console.Out.WriteLine("")
    Console.Out.WriteLine(Yellow("USAGE:")) ; TODO: bold yellow
    Console.Out.WriteLine(Format("  {1} {2} {3}", Green(A_ScriptName), Cyan("[options]"), Magenta("[path]")))
    Console.Out.WriteLine("")
    Console.Out.WriteLine(Yellow("ARGUMENTS:"))
    Arg("path", "File or directory containing files to lint", "cwd")
    Console.Out.WriteLine("")
    Console.Out.WriteLine(Yellow("OPTIONS:"))
    Opt(["-c", "--config"], "Path to the config file to use", "discovered automatically")
    Opt(["-t", "--target"], "Target AutoHotkey version. Overrides the config file if present", "2.0.26")
    Opt(["-s", "--sarif"], "Path to write SARIF output to, or '-' for stdout")
    opt(["-f", "--fix"], "Apply autofixes to linted files")
    opt(["-w", "--watch"], "Lint again whenever the file or directory changes")
    opt(["--apply-suggestions"], "Apply suggested fixes to linted files (may be incorrect)")

    Console.Out.WriteLine("")
    opt(["--no-color"], "Disable ANSI colors. Also respects the NO_COLOR environment variable")
    opt(["-v", "--version"], "Show the program version and exit")
    opt(["-?", "-h", "--help"], "Show this message and exit")
}

ShowVersion() {
    Console.Out.WriteLine(AHKLINT_VERSION)
    ExitApp(0)
}

/**
 * Parse CLI arguments into an output object
 * 
 * @param {Array<String>} argv the arguments to parse 
 * @returns {CliArgs} the parsed arguments
 */
ParseArgs(argv) {
    out := CliArgs()

    i := 1
    while i <= argv.Length {
        arg := argv[i]
        switch arg {
            case "-c", "--config":
                if i == argv.Length
                    Die("--config requires a path")
                out.configPath := argv[++i]
            case "-t", "--target":
                if i == argv.Length
                    Die("--target requires a version")
                out.target := argv[++i]
            case "--no-color":
                out.noColor := true
            case "-v", "--version":
                out.showVersion := true
            case "-?", "-h", "--help":
                out.showHelp := true
            case "-f", "--fix":
                out.fix := true
            case "-s", "--sarif":
                if i == argv.Length
                    Die("--sarif requires a path")
                out.sarifPath := argv[++i]
            case "--apply-suggestions":
                out.applySuggestions := true
            case "-w", "--watch":
                out.watch := true
            default:
                if SubStr(arg, 1, 1) == "-"
                    Die("unknown option: " arg)
                if out.file == "" {
                    out.file := arg
                } else {
                    Die("unrecognized argument: " arg)
                }
        }
        i++
    }

    ; A watch never finishes, and SARIF is one document describing a finished run
    if out.watch && out.sarifPath != ""
        Die("--watch cannot be combined with --sarif")

    return out
}