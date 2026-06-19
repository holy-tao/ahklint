# CONTRIBUTING

Contributions are welcome in the form of Pull Requests.

## Adding new Lints

A lint is a class with **static `meta`** block and a constructor **`__New(linter)`** which defines the behavior. `meta`
is the single source of truth for discovery, config validation, doc linking, severity, and version applicability.

The linter instantiates the lint **once per file** (`lint := LintClass(context)`), so you can track state if you need it
on an instance of your lint class. `meta` is static and read-only. In the constructor, the lint registers the node types
it cares about via `context.OnEnter` / `context.OnExit`.

> [!IMPORTANT]
> The name of the class must match the name of the file it is in - for example, the class below must be inside
> `NoGotos.ahk`. Build scripts will assume your lint class names match filenames and builds will break if they do not.

``` autohotkey
class NoGotos {
    static meta := {
        id:          "no-goto",            ; stable string ID
        title:       "Disallow Goto",
        category:    "misc",               ; for grouping, not a category ID
        versions:    ">=2.0",              ; applicability range (VerCompare'd with the declared version of the linted file)
        severity:    "off",                ; default severity
        fixable:     "suggestion",         ; "auto" | "suggestion" | "none"
        recommended: false,                ; member of the "recommended" preset?
        references:  [                      ; external "see also" links
            "https://www.autohotkey.com/docs/v2/lib/Goto.htm"
        ]
    }

    static message => "The use of Goto is discouraged. Consider using Else, Blocks, Break, and Continue as substitutes for Goto."

    ; Register callbacks for the linter tree walk here
    __New(linter) {
        ; Simple lint - report on every goto statement.
        linter.OnEnter("goto_statement",
            (visitor, node) => visitor.Report(NoGotos.meta, node, NoGotos.message))
    }
}
```

### Documentation and Tests

Documentation and tests live beside the lint classes in `<lint-name>.md` files.

The linter test harness pulls test cases from the .md documentation files in the [lints](../lints/) directory. Any
fenced autohotkey code block can be a test if it has the fence-open `autohotkey test` (case-insensitive). A test
identifies the lints it expects to fire with the syntax `;~ <lint-name>`.

For example, the below is a test that expects the lint `no-goto` to fire on line 1 of the code block.

````text
``` autohotkey test
goto label ;~ no-goto

label:
MsgBox("At label!")
```
````

Correct examples should simply omit any `;~ <lint-name>` markers. A test will fail if any unexpected lints fire or if
any expected lints fail to fire.

Your `lint.md` file is also used in the generated website and will be linked to in linter output. The doc URL is
derived automatically from your `meta.id` (`https://holy-tao.github.io/ahklint/lints/<id>`) — don't add a `docs:`
field to `meta`. Every lint must ship a `.md` with at least one `;~ <id>` example, or the docs build will fail.
