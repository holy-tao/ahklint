Line comments should have exactly one space between the `;` and the rest of the comment.

By default, this lint also alerts on empty line comments.

## Examples

### Incorrect

```autohotkey test
MsgBox("Hello, World!") ;Shows a message box ;~ line-comment-spacing
MsgBox("From AhkLint!") ;  Preceded by two spaces ;~ line-comment-spacing
```
<!-- markdownlint-disable MD010 -->
```autohotkey test
MsgBox("Hello, World!") ;	The lint also reports comments by non-space characters, e.g. tabs ;~ line-comment-spacing
```
<!-- markdownlint-enable MD010 -->

```autohotkey test { "allowEmpty": false }
MsgBox("Hello, World!") ; ;~ line-comment-spacing
```

### Correct

```autohotkey test
MsgBox("Hello, World!") ; Shows a message box
```

```autohotkey test { "allowEmpty": true }
MsgBox("Hello, World!") ;
```
