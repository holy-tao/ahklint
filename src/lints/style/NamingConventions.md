Use this lint to enforce naming conventions for classes, structs, functions, methods, properties, and variables.
AutoHotkey identifiers are case-insensitive, so the case of a name usually has no effect on your script. But
inconsistent naming makes your code harder to scan.

Each kind of name takes one of the styles `PascalCase` or `camelCase`, or `off` to skip that kind. Parameters,
`for` loop variables, `catch` variables, and declared variables count as variables. Object literal keys count as
properties. The lint reports a variable once per scope, at its first binding. The lint does not examine member
assignments such as `obj.name := 1`.

A name can start with one or more `_` characters, for private members and [meta-functions]. The lint examines
the name without them. For example, `_PrivateMethod` is PascalCase. Meta-functions are case-insensitive too, so
the method style applies to them: `__New` is PascalCase and `__new` is camelCase.

The lint always allows UPPER_SNAKE_CASE names, such as `MAX_RETRIES`, for every kind of name. AutoHotkey has no
constants, so the lint cannot tell a constant from any other name.

[meta-functions]: https://www.autohotkey.com/docs/alpha/Objects.htm#Meta_Functions

## Examples

### Correct

```autohotkey test { "class": "PascalCase", "method": "PascalCase" }
class ExampleClass {
    __New() {
        this.Greet()
    }

    Greet() => MsgBox "hello, world!"
}
```

```autohotkey test { "method": "camelCase", "variable": "camelCase" }
class Greeter {
    static MAX_GREETINGS := 3

    __new(greeting) {
        this.greeting := greeting
    }

    greet(name) {
        message := this.greeting ", " name
        message := message "!"
        MsgBox message
    }
}
```

<details>
<summary>More correct examples</summary>

Every kind of name in PascalCase:

```autohotkey test { "class": "PascalCase", "struct": "PascalCase", "function": "PascalCase", "method": "PascalCase", "property": "PascalCase", "variable": "PascalCase" }
struct Point {
    X: i32
    Y: i32
}

class _PrivateClass {
    static Instances := 0
    Name := ""
    Label => this.Name
    Item[Index] => Index
    Size {
        get => 0
    }

    __New(Name) {
        this.Name := Name
    }

    _Helper(&OutValue, Count?, Extra := 1, Rest*) {
        OutValue := Count ?? Extra
    }
}

FormatAll(Items, *) {
    static CallCount := 0
    Result := ""
    for Index, Item in Items
        Result .= Item
    try Result := Trim(Result)
    catch Error as Err
        MsgBox Err.Message
    return Result
}

Double := Num => Num * 2
Square := (Num) => Num * Num
Callback := (Value) {
    return Value
}
```

The same code in camelCase:

```autohotkey test { "class": "camelCase", "struct": "camelCase", "function": "camelCase", "method": "camelCase", "property": "camelCase", "variable": "camelCase" }
struct point {
    xPos: i32
    yPos: i32
}

class _privateClass {
    static instances := 0
    name := ""
    label => this.name
    item[index] => index
    size {
        get => 0
    }

    __new(name) {
        this.name := name
    }

    _helper(&outValue, count?, extra := 1, rest*) {
        outValue := count ?? extra
    }
}

formatAll(items, *) {
    static callCount := 0
    result := ""
    for index, item in items
        result .= item
    try result := Trim(result)
    catch Error as err
        MsgBox err.Message
    return result
}

double := num => num * 2
square := (num) => num * num
callback := (value) {
    return value
}
```

UPPER_SNAKE_CASE names are legal in every style:

```autohotkey test { "class": "camelCase", "method": "camelCase", "property": "camelCase", "variable": "camelCase" }
class HTTP_CLIENT {
    static DEFAULT_TIMEOUT := 30
    static RETRIES => 3

    SEND(URL) {
        return URL
    }
}

MAX_SIZE := 100
X := 1
```

The lint does not examine member assignments, index assignments, or compound assignments:

```autohotkey test { "variable": "camelCase" }
counter := {}
counter.Total := 0
counter.Total += 1
Settings.Default := "value"
values := []
values.Push(0)
values[1] := 2
Total += 1
```

The lint does not examine a kind with the style `off`:

```autohotkey test { "class": "off", "struct": "off", "function": "off", "method": "off", "property": "off", "variable": "off" }
struct point_2d {
    x_pos: i32
}

class my_class {
    some_prop := 1

    do_thing(some_param) {
        local_var := some_param
    }
}

my_func(Param) => Param
```

</details>

### Incorrect

```autohotkey test { "class": "PascalCase", "property": "camelCase" }
class camelCase { ;~ naming-conventions
    Property => "bad!" ;~ naming-conventions
}
```

```autohotkey test { "function": "camelCase", "variable": "camelCase" }
Greet(Name) { ;~ naming-conventions 2
    Message := "hello, " Name ;~ naming-conventions
    for Index, char in StrSplit(Message) ;~ naming-conventions
        OutputDebug char
}
```

<details>
<summary>More incorrect examples</summary>

Names that are not PascalCase:

```autohotkey test { "class": "PascalCase", "struct": "PascalCase", "function": "PascalCase", "method": "PascalCase", "property": "PascalCase", "variable": "PascalCase" }
struct point { ;~ naming-conventions
    x: i32 ;~ naming-conventions
}

class myClass { ;~ naming-conventions
    static instances := 0 ;~ naming-conventions
    name := "" ;~ naming-conventions
    label => this.name ;~ naming-conventions
    item[Index] => Index ;~ naming-conventions
    size { ;~ naming-conventions
        get => 0
    }

    __new() { ;~ naming-conventions
    }

    do_thing(&outValue, count?, Extra := 1, rest*) { ;~ naming-conventions 4
        outValue := count
    }
}

formatAll(items) { ;~ naming-conventions 2
    static callCount := 0 ;~ naming-conventions
    for index, Item in items ;~ naming-conventions
        MsgBox Item
    try FileDelete("x")
    catch as err ;~ naming-conventions
        MsgBox err.Message
}

double := num => num * 2 ;~ naming-conventions 2
callback := (value) { ;~ naming-conventions 2
    return value
}
some_really_long_snake_case_name := 1 ;~ naming-conventions

objectLiteral := { camelCase: 42 } ;~ naming-conventions 2
```

Names that are not camelCase:

```autohotkey test { "class": "camelCase", "struct": "camelCase", "function": "camelCase", "method": "camelCase", "property": "camelCase", "variable": "camelCase" }
struct Point { ;~ naming-conventions
    XPos: i32 ;~ naming-conventions
}

class MyClass { ;~ naming-conventions
    static Instances := 0 ;~ naming-conventions
    Name := "" ;~ naming-conventions
    Label => this.Name ;~ naming-conventions
    Size { ;~ naming-conventions
        get => 0
    }

    __New() { ;~ naming-conventions
    }

    DoThing(&OutValue, count?, extra := 1, Rest*) { ;~ naming-conventions 3
    }
}

FormatAll(items) { ;~ naming-conventions
    static CallCount := 0 ;~ naming-conventions
    for Index, item in items ;~ naming-conventions
        MsgBox item
    try FileDelete("x")
    catch as Err ;~ naming-conventions
        MsgBox Err.Message
}

Double := Num => Num * 2 ;~ naming-conventions 2
(Wrapped) := 1 ;~ naming-conventions
some_really_long_snake_case_name := 1 ;~ naming-conventions
```

The lint reports a variable once in each scope, at its first binding. A closure shares the variables of its
enclosing function:

```autohotkey test { "variable": "camelCase" }
Total := 0 ;~ naming-conventions
Total := 1
TOTAL := 2

First() {
    Count := 0 ;~ naming-conventions
    Count := Count + 1
    Increment() {
        Count := Count + 1
    }
}

Second() {
    Count := 0 ;~ naming-conventions
}
```

</details>
