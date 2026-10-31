---
title: ahklint
type: docs
---

<!-- markdownlint-disable-next-line MD025 -->
# AhkLint

An AutoHotkey v2 / v2.1 linter, written in AutoHotkey.

Every diagnostic links here, to the page for the lint that produced it. Browse the full set under
**[Lints]({{< relref "/lints" >}})**, or take a look at **[Configuration]({{< relref "/config" >}})** or the
**[CLI]({{< relref "/cli" >}})** reference.

```text
C:\Example\ahklint\example.ahk:4:5 [fileappend-loop] warn:
Line |
   4 |     FileAppend(line, "output.txt")
     |     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Open and close the file outside of the loop instead of calling FileAppend
     | See: https://holy-tao.github.io/ahklint/lints/fileappend-loop
```

## Install

Download the latest stable version from [releases](https://github.com/holy-tao/ahklint/releases/latest).

You can download the absolute latest build from the artifacts section of the most recent succesful
[ci run](https://github.com/holy-tao/ahklint/actions/workflows/ci.yml) on GitHub.
