# ahklint

An AutoHotkey v2 / v2.1 linter. See the [website](https://holy-tao.github.io/ahklint/) for detailed usage
information and the full list of lints.

```text
C:\Example\ahklint\example.ahk:4:5 [fileappend-loop] warn:
Line |
   4 |     FileAppend(line, "output.txt")
     |     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Open and close the file outside of the loop instead of calling FileAppend
     | See: https://holy-tao.github.io/ahklint/lints/fileappend-loop
```

## Installation

Download the latest stable version from [releases](https://github.com/holy-tao/ahklint/releases/latest).

You can download the absolute latest build from the artifacts section of the most recent succesful
[ci run](https://github.com/holy-tao/ahklint/actions/workflows/ci.yml) on GitHub.
