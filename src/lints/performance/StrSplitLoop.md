If you don't need to save the resulting array, using a [parsing loop][loop-parse] is more memory efficient
than calling [`StrSplit`][StrSplit]. Parsing loops use less memory overall and avoid creating an intermediate
array of all the split values. The benefits are larger when parsing very large strings, like when parsing entire
files.

Inside the loop, [`A_Index`][A_Index] stands in for the array index and [`A_LoopField`][A_LoopField] for the
item.

[StrSplit]: https://www.autohotkey.com/docs/alpha/lib/StrSplit.htm
[loop-parse]: https://www.autohotkey.com/docs/alpha/lib/LoopParse.htm
[A_Index]: https://www.autohotkey.com/docs/alpha/Variables.htm#Index
[A_LoopField]: https://www.autohotkey.com/docs/alpha/lib/LoopParse.htm#LoopField

## Examples

### Incorrect

```autohotkey test
for cell in StrSplit(csvLine, ",", " `r`n`t") { ;~ strsplit-loop
    ; do stuff...
}
```

It fires for both forms of `for`, with or without parentheses, and when `Delimiters` is left out:

```autohotkey test
for i, item in StrSplit(myString, ",") { ;~ strsplit-loop
    items[i] := item
}

for (char in StrSplit(word)) ;~ strsplit-loop
    MsgBox char

for line in strsplit(text, , "`r") { ;~ strsplit-loop
    ; do stuff...
}
```

An array of single-character delimiters becomes a delimiter list, as does a `MaxParts` of `-1` (no limit):

```autohotkey test
for word in StrSplit(sentence, [A_Space, A_Tab, "`n"]) { ;~ strsplit-loop
    ; do stuff...
}

for field in StrSplit(record, "|", , -1) { ;~ strsplit-loop
    ; do stuff...
}
```

### Correct

```autohotkey test
loop parse csvLine, ",", " `r`n`t" {
    ; do stuff...
}
```

[Parsing loops][loop-parse] have no equivalent to the `MaxParts` parameter of [`StrSplit`][StrSplit], so the lint
won't fire if you use it:

```autohotkey test
for part in StrSplit(iniLine, "=", " `r`n`t", 2) {
    ; do stuff...
}
```

`StrSplit` treats each delimiter as a whole string, where a parsing loop splits on every character of its
delimiter list, and treats `"CSV"` as a keyword. So the lint only fires when every delimiter is a single
character. Multi-character delimiters, and delimiters it can't see the value of, are left alone:

```autohotkey test
for row in StrSplit(text, "`r`n") {
    ; do stuff...
}

for cell in StrSplit(text, "CSV") {
    ; do stuff...
}

for token in StrSplit(text, [",", "->"]) {
    ; do stuff...
}

for token in StrSplit(text, separator) {
    ; do stuff...
}
```

If you _do_ need to save the resulting array, the lint won't complain:

```autohotkey test
for part in parts := StrSplit(iniLine, "=", " `r`n`t") {
    ; do stuff...
}
```

Nor does it fire when the array isn't what the loop iterates over, or when the call isn't the built-in `StrSplit`:

```autohotkey test
parts := StrSplit(iniLine, "=")

for part in Reverse(StrSplit(iniLine, "=")) {
    ; do stuff...
}

for part in myObj.StrSplit(iniLine, "=") {
    ; do stuff...
}

for part in StrSplit(splitArgs*) {
    ; do stuff...
}
```
