---
title: CLI
type: docs
weight: 20
---

<!-- markdownlint-disable-next-line MD025 -->
# CLI

`ahklint` is a command-line tool.

It requires `tree-sitter.dll` and `tree-sitter-autohotkey.dll` to be in a `./bin` directory, relative to the CLI's
location on disk.

## Usage

```bash
ahklint.exe                             # lint every file in the cwd
ahklint.exe ./path/to/script.ahk        # lint script.ahk
ahklint.exe ./path/to/script.ahk --fix  # automatically fix violations
ahklint.exe ./src ./tools/build.ahk     # lint a directory and a file
```

By default, `ahklint` does a one-off lint of the files and directories it is given. If a [`path`](#paths) is a
directory, it lints every `.ahk` file in it and any of its subdirectories.

## CLI Arguments Reference

### Positional Arguments

#### paths

```bash
ahklint.exe ./path/to/directory ./path/to/script.ahk
```

Determines the file or files to lint. By default, every `.ahk` file in the current working directory is linted. You
can pass any number of directories, files, or both. For a directory, _every_ `.ahk` file in it or any of its
subdirectories is linted. A file reached through more than one path is only linted once.

All of the paths are linted with one configuration file, discovered from the first path. Use
[`--config`](#--config--c) to choose it explicitly.

### Options

#### --config, -c

```bash
ahklint.exe --config ./path/to/ahklint.json
```

Specify the [configuration file]({{< relref "/config" >}}) to use instead of discovering it automatically.

By default, `ahklint` discovers your config file by walking up directories from the first path it is given (or the
current working directory, if none is); this flag overrides that behavior.

#### --target, -t

```bash
ahklint.exe --target v2.1-alpha.32
```

Set or override the target AutoHotkey version. This is not necessary if `target` is set in the
[configuration file]({{< relref "/config" >}}), and overrides it if it is.

#### --sarif, -s

```bash
ahklint.exe --sarif ./reports/sarif.json
```

Specify a path at which to write a [sarif](https://sarifweb.azurewebsites.net/) file. This file can be uploaded to
GitHub or the ci/cd pipeline of your choice.

Has no effect when `--watch` is present.

#### --fix, -f

```bash
ahklint.exe --fix
```

Apply fixes to lints automatically.

#### --watch, -w

```bash
ahklint.exe --watch
```

Watch the target file or directory for changes and re-lint whenever they change. Only one path can be watched. This
can be combined with `--fix` and `--apply-suggestions` (if desired) to approximate editors' format-on-save behavior.

`--watch` cannot be used if more than one path is specified.

#### --apply-suggestions

```bash
ahklint.exe --fix --apply-suggestions
```

Apply suggestions to linted files automatically. Has no effect when `--fix` is not present.

> [!WARNING]
> Suggestions, unlike fixes, are not guaranteed to be safe and may change runtime behavior.

Suggestions are "fixes" which are opinionated or potentially unsafe.

### Other Options

| Option | Description |
| ------ | ----------- |
| `--no-color` | Turn of ANSI colors. The CLI respects the [no-color](https://no-color.org/) conventions; you can also disable ANSI colors by setting the `NO_COLOR` environment variable to any non-empty value. |
| `--version`, `-v` | Show the program version and exit. |
| `--help`, `-h` | Show the program help and exit. |
