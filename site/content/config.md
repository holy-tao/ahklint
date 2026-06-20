---
title: Configuration
type: docs
weight: 1
bookCollapseSection: true
---

<!-- markdownlint-disable-next-line MD025 -->
# Configuration

AhkLint is configured with a json file named either `.ahklint.json` or `ahklint.json`.

## Schema

The configuration schema is similar to that of ESLint:

```json
{
    "target":  "2.1-alpha.30",
    "extends": "recommended",
    "lints": {
        "no-goto":      "error",
        "one-requires": ["warn", {}]
    }
}
```

### Target

The target version of the AutoHotkey interpreter. Lints declare which version(s) they apply to as
[`VerCompare`]-compatible strings. These identifiy the range of versions for which they are relevant. When the
lint registry is compiled at startup, lints for which `VerCompare(target, lint.version)` returns false are exluded
from the run.

> [!IMPORTANT]
> `target` must be an absolute version, not a version range. We cannot compare two ranges for overlaps. In practice,
> `target` must be a value which is legal as the *first* argument to [`VerCompare`].

If not set, `target` defaults to `2.0.26`, the current stable version of the interpreter at time of writing. A
warning is emitted if the target  version is not set in config or specified via the `--target` CLI flag.

See also: [`A_AhkVersion`]

[`VerCompare`]: https://www.autohotkey.com/docs/alpha/lib/VerCompare.htm
[`A_AhkVersion`]: https://www.autohotkey.com/docs/alpha/Variables.htm#AhkVersion

### Extends

If `extends` is present, it determines the default behavior of AhkLint when the config file does not specify what to do.
If present, `extends` must be one of the following.

| Value | Behavior |
| --- | --- |
| `recommended` | The config extends the recommended set of lints. Check the table at the top of a lint's help page to see if it's recommended, and what its default severity is. |
| `all` | All lints are enabled unless explicitly disabled by the config. |
| `none` | All lints are *disabled* unless explicitly enabled by the config. |

If not set, the default value is `recommended`.

### Lints

`lints` is where you can configure the behavior of specific lints. Lints are identified by ID, which is a kebab-case
name loosly describing its behavior. The list is keyed by lint ID, and the value can be either one of the following
strings to indicate severity:

- `off`
- `warn`
- `error`

Or an array with exactly two items, where the first item is one of the above strings and the second is an object
containing lint-specific configuration options. Every lint also has a default severity and config, see the indivudal
lint pages for details.
