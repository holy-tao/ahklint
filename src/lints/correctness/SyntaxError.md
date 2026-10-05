The tree failed to parse because of a syntax error.

It this looks like a false positive (the interpreter loads and executes the script), please write an issue against
the [tree-sitter grammar][grammar]'s repository.

Note that this generally doesn't invalidate the rest of the reported lints. `ahklint` uses [tree-sitter] to parse
source files, and its error recovery is quite advanced. Only lints in the subtree of the node with the syntax error
should be treated as suspicious.

[grammar]: https://github.com/holy-tao/tree-sitter-autohotkey
[tree-sitter]: https://tree-sitter.github.io/tree-sitter/

## Examples

### Incorrect

```autohotkey test
class MissingClosingBrace {
    property := 42 ;~ syntax-error

```
