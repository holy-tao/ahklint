# Tests

The linter test harness pulls test cases from the .md documentation files in the [lints](../lints/) directory. Any fenced autohotkey code block can be a test if it has the fence-open `autohotkey test` (case-insensitive). A test identifies the lints it expects to fire with the syntax `;~ <lint-name>`.

For example, the below is a test that expects the lint `no-goto` to fire on line 1 of the code block.


````text
``` autohotkey test
goto label ;~ no-goto

label:
MsgBox("At label!")
```
````

Correct examples should simply omit any `;~ <lint-name>` markers. A test will fail if any unexpected lints fire or if any expected lints fail to fire.