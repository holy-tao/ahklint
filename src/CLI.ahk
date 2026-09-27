#Requires AutoHotkey v2.1-alpha.30

#Import "Colors" { Red }
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
    sarifPath := ""
    fix := false
}

Die(message) {
    Console.err.WriteLine(Red("ahklint: ") message)
    Console.err.WriteLine("usage: ahklint [--config <path>] [--target <ver>] [--sarif <path>] [--no-color] [--fix] <file.ahk>")
    Console.err.WriteLine("       ahklint --version")
    ExitApp(2)
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
            case "--config":
                if (i == argv.Length)
                    Die("--config requires a path")
                out.configPath := argv[++i]
            case "--target":
                if (i == argv.Length)
                    Die("--target requires a version")
                out.target := argv[++i]
            case "--no-color":
                out.noColor := true
            case "--version":
                ShowVersion() ; does not return
            case "--fix":
                out.fix := true
            case "--sarif":
                if (i == argv.Length)
                    Die("--sarif requires a path")
                out.sarifPath := argv[++i]
            default:
                if (SubStr(arg, 1, 2) == "--")
                    Die("unknown option: " arg)
                if (out.file == "")
                    out.file := arg
        }
        i++
    }
    return out
}