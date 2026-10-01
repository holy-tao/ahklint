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
```

By default, `ahklint` does a one-off lint of either a single file or a directory containing files. If [`path`](#path)
is a directory, it lints every `.ahk` file in it and any of its subdirectories.

## CLI Arguments Reference

### Positional Arguments

#### path

```bash
ahklint.exe ./path/to/directory
```

Determines the file or files to lint. By default, every `.ahk` file in the current working directory is linted. You
can pass an explicit filepath to lint every file in a directory, or a specific file. If this is directory, _every_
`.ahk` file in it or any of its subdirectories is linted.

> [!NOTE]
> `ahklint` does not currently support excluding or including files or directories by extension, path, glob, etc, but
> should in the future.

### Options

#### --config, -c

```bash
ahklint.exe --config ./path/to/ahklint.json
```

Specify the [configuration file]({{< relref "/config" >}}) to use instead of discovering it automatically.

By default, `ahklint` discovers your config file by walking up directories from its current working directory; this
flag overrides that behavior.

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

Watch the target file or directory for changes and re-lint whenever they change. This can be combined with `--fix`
and `--apply-suggestions` (if desired) to approximate editors' format-on-save behavior.

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
