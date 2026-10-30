
Outside of a [file-reading loop][loop-files] with an output file, [`FileAppend`][FileAppend] will open and close the
target file every time it is called. Inside a loop, this is almost always pointless overhead. Instead, open the file
you want to write to outside of the loop, write your data, and close it when your loop exits.

> [!NOTE]
> If you need to flush the data to the file, accessing it's [`handle`][file-handle] property will write any buffered
> data back to disk without closing it.

[FileAppend]: https://www.autohotkey.com/docs/v2/lib/FileAppend.htm
[loop-files]: https://www.autohotkey.com/docs/v2/lib/LoopRead.htm
[file-handle]: https://www.autohotkey.com/docs/v2/lib/File.htm#Handle

## Examples

### Incorrect

```autohotkey test
for line in lines {
    FileAppend(line, "output.txt") ;~ fileappend-loop
}
```

```autohotkey test
while source.HasData() {
    FileAppend(source.GetData() "`n", "output.txt") ;~ fileappend-loop
}
```

```autohotkey test
loop data.length {
    FileAppend(data[A_Index] "`n", "output.txt") ;~ fileappend-loop
}
```

```autohotkey test
; this file-reading loop doesn't have an output file, so FileAppend will still
; open and close the target file every time
loop read "input.txt" {
    FileAppend(StrUpper(A_LoopReadLine), "output.txt") ;~ fileappend-loop
}
```

### Correct

```autohotkey test
output := FileOpen("output.txt", "W")
for line in lines {
    output.WriteLine(line)
    _ := output.handle ; flush to disk
}
output.Close()
```

```autohotkey test
; Inside a file-reading loop, FileAppend is allowed and is the preferred way to write
; output to a file
loop read "input.txt", "output.txt" {
    FileAppend(StrUpper(A_LoopReadLine))
}
```
