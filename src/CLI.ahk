#Requires AutoHotkey v2.1-alpha.30

#Import "Colors" { Red, Cyan, Magenta, Yellow, Green, Gray }
#Import "utils\Console" { Console }
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
}

Die(message) {
    ShowHelp()
    Console.err.WriteLine(Red("ahklint: ") message)
    ExitApp(2)
}

/**
 * Shows the CLI help text. Does not exit the program.
 */
ShowHelp() {
    static LEFT_COLUMN_WIDTH := 16

    Arg(arg, desc, default := "") {
        str := "  " Magenta(arg)
        padding := LEFT_COLUMN_WIDTH - StrLen(arg)
        loop Max(0, padding)
            str .= " "

        str .= desc
        if default {
            str .= Gray(" [default: " default "]")
        }
        Console.out.WriteLine(str)
    }

    Opt(flags, desc, default := "") {
        str := "  "
        for f in flags.Map(f => Cyan(f)) {
            str .= f . ((A_Index == flags.Length) ? "" : ", ")
        }

        padding := LEFT_COLUMN_WIDTH - (flags.SumBy(StrLen) + (2 * (flags.Length - 1)))
        loop Max(0, padding)
            str .= " "

        str .= desc

        if default {
            str .= Gray(" [default: " default "]")
        }

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
    Opt(["-s", "--sarif"], "Path to write SARIF output to")
    opt(["-f", "--fix"], "Apply autofixes to linted files")

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
    while (i <= argv.Length) {
        arg := argv[i]
        switch arg {
            case "-c", "--config":
                if (i == argv.Length)
                    Die("--config requires a path")
                out.configPath := argv[++i]
            case "-t", "--target":
                if (i == argv.Length)
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
                if (i == argv.Length)
                    Die("--sarif requires a path")
                out.sarifPath := argv[++i]
            default:
                if (SubStr(arg, 1, 1) == "-")
                    Die("unknown option: " arg)
                if (out.file == "") {
                    out.file := arg
                } else {
                    Die("unrecognized argument: " arg)
                }
        }
        i++
    }

    return out
}