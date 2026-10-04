#Requires AutoHotkey v2.0

; Hand-written unit tests for the config/version machinery - the stateful,
; non-doc-derived logic that the example fixtures (RunTests.ahk) can't cover.
; Recorded into the same JUnit writer so they share junit.xml and the exit code.

#Import "../src/Config.ahk" { Config }
#Import "../src/Linter.ahk" { DEFAULT_TARGET }
#Import "../src/LintRun.ahk" { LintRun }
#Import "../src/SourceText.ahk" { SourceText }
#Import "../src/formatters/SarifFormatter.ahk" { CreateSarif }
#Import "../src/Fix.ahk" { FixToFixpoint }

; Controlled lints so resolution is deterministic regardless of the real set.

class _FakeRecommended {
    static meta => { id: "fake-rec", title: "", category: "x", versions: ">=2.0",
        severity: "warn", fixable: "none", recommended: true, references: [] }
}
class _FakeOptional {
    static meta => { id: "fake-opt", title: "", category: "x", versions: ">=2.0",
        severity: "warn", fixable: "none", recommended: false, references: [] }
}
class _FakeNewOnly {
    static meta => { id: "fake-new", title: "", category: "x", versions: ">=2.1-alpha.24",
        severity: "error", fixable: "none", recommended: true, references: [] }
}

class _FakeWithOptions {
    static meta => { id: "fake-options", title: "", category: "x", versions: ">=2.0",
        severity: "warn", fixable: "none", recommended: true, references: [],
        options: {
            mode:  { type: "string",  default: "a", values: ["a", "b"] },
            flag:  { type: "boolean", default: true },
            limit: { type: "number",  default: 80 }
        } }
}

_FakeRegistry() => [_FakeRecommended, _FakeOptional, _FakeNewOnly, _FakeWithOptions]

; Config with the given options map on fake-options
_OptionsConfig(opts) =>
    Config(Map("lints", Map("fake-options", ["warn", opts])), _FakeRegistry(), "2.0", ["**/*.ahk"], [])

/**
 * A SARIF log for a two-file run with every lint enabled: one file with a
 * non-ASCII line and a `no-cdecl` finding, and one file that failed to lint.
 * Round-tripped through JSON, so the tests see what a consumer would.
 */
_SarifLog() {
    static log := ""
    if log != ""
        return log

    root := A_Temp "\ahklint-sarif-test"
    code := 'x := "日本語", DllCall("f", "cdecl int")`n'
    buf := Buffer(StrPut(code, "UTF-8") - 1)
    StrPut(code, buf, "UTF-8")

    cfg := Config(Map("extends", "all"), ALL_LINTS, "2.1-alpha.30", ["**/*.ahk"], [])
    run := LintRun(cfg)
    run.AddFile(root "\a.ahk", SourceText(buf), Linter(AutoHotkeyLang(), buf, cfg).Run())
    run.AddError(root "\b.ahk", Error("boom"))

    return log := JSON.Parse(JSON.Dump(CreateSarif(run, root)))
}

/** The `no-cdecl` result from _SarifLog. */
_SarifCdeclResult() {
    for result in _SarifLog()["runs"][1]["results"]
        if result["ruleId"] == "cdecl"
            return result
    throw Error("no cdecl result")
}

/** `text` as UTF-8 bytes with no terminator, the way a file is read. */
_Utf8(text) {
    buf := Buffer(StrPut(text, "UTF-8") - 1)
    StrPut(text, buf, "UTF-8")
    return buf
}

_Text(buf) => StrGet(buf, buf.Size, "UTF-8")

/**
 * A stand-in for a lint run: one finding on the first `from` in the source,
 * whose fix replaces it with `to`.
 */
_ReplaceFirst(from, to, fixable := "auto") => (source) {
    at := InStr(_Text(source), from, true)
    if !at
        return []
    return [{ code: "fake-fix", HasFix: true, fixable: fixable,
        fixes: [{ startByte: at - 1, endByte: at - 1 + StrLen(from), newText: to }] }]
}

/**
 * The scopes of `code`, after a full walk. A lint that uses the tracker has to be enabled for the
 * linter to build one.
 *
 * @returns {ScopeTracker}
 */
_Scopes(code) {
    buf := _Utf8(code)
    cfg := Config(Map("extends", "none", "lints", Map("unused-variable", "error")), ALL_LINTS, "2.1-alpha.30", ["**/*.ahk"], [])
    engine := Linter(AutoHotkeyLang(), buf, cfg)
    engine.Run()
    return engine.scopes
}

/**
 * Run every unit case, recording each into the shared JUnit writer.
 */
RunUnitTests(writer) {
    stdout := FileOpen("*", "w", "UTF-8")
    stdout.WriteLine("Running unit tests ...")

    for name, fn in _UnitCases() {
        t0 := A_TickCount
        try {
            fn()
            writer.Update("UnitTests", name, true, (A_TickCount - t0) / 1000)
            stdout.WriteLine("  ok   " name)
        } catch as e {
            err := Error(e.message)
            err.File := A_LineFile
            err.Line := A_LineNumber
            err.Stack := e.stack
            writer.Update("UnitTests", name, err, (A_TickCount - t0) / 1000)
            stdout.WriteLine(Format("  FAIL {1}: {2}", name, e.message))
        }
    }
    _ := stdout.Handle
}

_Assert(cond, msg := "assertion failed") {
    if !cond
        throw Error(msg)
}

_Throws(fn, msg := "expected a throw but none occurred") {
    try
        fn()
    catch
        return
    throw Error(msg)
}

_UnitCases() {
    cases := Map()

    cases["config: default is recommended set"] := () {
        c := Config.Default(_FakeRegistry(), DEFAULT_TARGET)
        _Assert(c.SeverityFor("fake-rec") == "warn",  "rec enabled at meta.severity")
        _Assert(c.SeverityFor("fake-new") == "error", "new (rec) enabled at meta.severity")
        _Assert(c.SeverityFor("fake-opt") == "off",   "non-rec off by default")
        _Assert(!c.IsEnabled("fake-opt"),             "IsEnabled false for off")
    }
    cases["config: extends all"] := () {
        c := Config(Map("extends", "all"), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-opt") == "warn", "opt enabled under all")
    }
    cases["config: extends none"] := () {
        c := Config(Map("extends", "none"), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-rec") == "off", "rec off under none")
    }

    cases["config: enable optional via lints map"] := () {
        c := Config(Map("lints", Map("fake-opt", "error")), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-opt") == "error", "opt overridden to error")
        _Assert(c.SeverityFor("fake-rec") == "warn",  "rec still on from preset")
    }
    cases["config: disable recommended via lints map"] := () {
        c := Config(Map("lints", Map("fake-rec", "off")), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-rec") == "off", "rec silenced")
    }
    cases["config: tuple severity form"] := () {
        c := Config(Map("lints", Map("fake-rec", ["error", Map()])), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-rec") == "error", "tuple severity parsed")
    }

    cases["config: unknown lint id throws"] := () =>
        _Throws(() => Config(Map("lints", Map("nope", "warn")), _FakeRegistry(), "2.0", ["**/*.ahk"], []))
    cases["config: unknown extends throws"] := () =>
        _Throws(() => Config(Map("extends", "everything"), _FakeRegistry(), "2.0", ["**/*.ahk"], []))
    cases["config: invalid severity throws"] := () =>
        _Throws(() => Config(Map("lints", Map("fake-rec", "loud")), _FakeRegistry(), "2.0", ["**/*.ahk"], []))
    cases["config: severity is case-insensitive"] := () {
        c := Config(Map("lints", Map("fake-rec", "Error")), _FakeRegistry(), "2.0", ["**/*.ahk"], [])
        _Assert(c.SeverityFor("fake-rec") == "error", "severity normalized to lowercase")
    }

    cases["config: options default from meta"] := () {
        o := Config.Default(_FakeRegistry(), "2.0").OptionsFor("fake-options")
        _Assert(o.mode == "a" && o.flag == true && o.limit == 80, "all defaults present")
    }
    cases["config: options without declaration are empty"] := () {
        o := Config.Default(_FakeRegistry(), "2.0").OptionsFor("fake-rec")
        _Assert(ObjOwnPropCount(o) == 0, "no options")
    }
    cases["config: options merge over defaults"] := () {
        o := _OptionsConfig(Map("mode", "b", "flag", 0)).OptionsFor("fake-options")
        _Assert(o.mode == "b",   "mode overridden")
        _Assert(o.flag == 0,     "flag overridden")
        _Assert(o.limit == 80,   "limit kept its default")
    }
    cases["config: enum option normalizes case"] := () {
        o := _OptionsConfig(Map("mode", "B")).OptionsFor("fake-options")
        _Assert(o.mode == "b", "enum value normalized to declared spelling")
    }
    cases["config: OptionsFor returns a copy"] := () {
        c := Config.Default(_FakeRegistry(), "2.0")
        c.OptionsFor("fake-options").mode := "b"
        _Assert(c.OptionsFor("fake-options").mode == "a", "mutation didn't leak")
    }

    cases["config: unknown option throws"] := () =>
        _Throws(() => _OptionsConfig(Map("nope", 1)))
    cases["config: option outside enum throws"] := () =>
        _Throws(() => _OptionsConfig(Map("mode", "c")))
    cases["config: option of wrong type throws"] := () =>
        _Throws(() => _OptionsConfig(Map("limit", "eighty")))
    cases["config: non-boolean for boolean option throws"] := () =>
        _Throws(() => _OptionsConfig(Map("flag", 2)))
    cases["config: non-object options throws"] := () =>
        _Throws(() => _OptionsConfig("mode=b"))
    cases["config: oversized tuple throws"] := () =>
        _Throws(() => Config(Map("lints", Map("fake-options", ["warn", Map(), 1])), _FakeRegistry(), "2.0", ["**/*.ahk"], []))

    cases["sarif: results live inside the run"] := () {
        log := _SarifLog()
        _Assert(log["version"] == "2.1.0", "version")
        _Assert(!log.Has("results") && !log.Has("artifacts"), "nothing at the log root")
        _Assert(log["runs"].Length == 1, "one run")
        _Assert(log["runs"][1]["results"].Length > 0, "results in the run")
    }
    cases["sarif: ruleIndex points at the matching rule"] := () {
        run := _SarifLog()["runs"][1]
        rules := run["tool"]["driver"]["rules"]
        for result in run["results"]
            _Assert(rules[result["ruleIndex"] + 1]["id"] == result["ruleId"],
                "ruleIndex mismatch for " result["ruleId"])
    }
    cases["sarif: columns count UTF-16 units, not bytes"] := () {
        region := _SarifCdeclResult()["locations"][1]["physicalLocation"]["region"]
        ; `x := "日本語", DllCall("f", ` is 25 characters but 31 bytes
        _Assert(region["startLine"] == 1, "startLine")
        _Assert(region["startColumn"] == 26, "startColumn is " region["startColumn"])
        _Assert(region["endColumn"] == 37, "endColumn is " region["endColumn"])
    }
    cases["sarif: fixes carry the replacement"] := () {
        fixes := _SarifCdeclResult()["fixes"]
        replacements := fixes[1]["artifactChanges"][1]["replacements"]
        _Assert(replacements.Length == 1, "one replacement")
        _Assert(!InStr(replacements[1]["insertedContent"]["text"], "cdecl"), "cdecl removed")
        _Assert(replacements[1]["deletedRegion"]["startColumn"] == 26, "deletedRegion column")
    }
    cases["sarif: failed files become notifications"] := () {
        invocation := _SarifLog()["runs"][1]["invocations"][1]
        _Assert(invocation["executionSuccessful"] == 0, "run marked unsuccessful")
        notes := invocation["toolExecutionNotifications"]
        _Assert(notes.Length == 1 && InStr(notes[1]["message"]["text"], "boom"), "one notification")
    }
    cases["sarif: rules carry the doc introduction only"] := () {
        for rule in _SarifLog()["runs"][1]["tool"]["driver"]["rules"] {
            id := rule["id"]
            _Assert(rule["fullDescription"]["text"] != rule["shortDescription"]["text"],
                id ": fullDescription is just the title")
            _Assert(rule["help"]["text"] != "", id ": empty help.text")
            md := rule["help"]["markdown"]
            _Assert(!InStr(md, "``````") && !InStr(md, ";~"), id ": examples leaked into help")
        }
    }

    cases["fix: repeats until nothing is left to fix"] := () {
        lint := _ReplaceFirst("a", "b")
        source := _Utf8("aaa")
        fixed := FixToFixpoint(source, lint(source), lint)
        _Assert(_Text(fixed.source) == "bbb", "source is " _Text(fixed.source))
        _Assert(fixed.passes == 3, "passes is " fixed.passes)
        _Assert(fixed.converged, "converged")
        _Assert(fixed.diagnostics.Length == 0, "nothing left to report")
        _Assert(fixed.fixed.Length == 3, "fixed is " fixed.fixed.Length)
    }
    cases["fix: nothing to fix leaves the source alone"] := () {
        lint := _ReplaceFirst("a", "b")
        source := _Utf8("xyz")
        fixed := FixToFixpoint(source, lint(source), lint)
        _Assert(fixed.source == source, "same buffer")
        _Assert(fixed.passes == 0 && fixed.converged, "no passes, converged")
        _Assert(fixed.fixed.Length == 0, "nothing fixed")
    }
    cases["fix: suggestions are only applied on request"] := () {
        lint := _ReplaceFirst("a", "b", "suggestion")
        source := _Utf8("a")
        skipped := FixToFixpoint(source, lint(source), lint)
        _Assert(skipped.passes == 0 && skipped.diagnostics.Length == 1, "suggestion left reported")
        applied := FixToFixpoint(source, lint(source), lint, true)
        _Assert(_Text(applied.source) == "b", "suggestion applied")
    }
    cases["fix: a multi-edit fix is applied whole or not at all"] := () {
        ; `wrap` wants to parenthesize "bc", but its closing edit collides with `swap`
        swap := { code: "swap", HasFix: true, fixable: "auto",
            fixes: [{ startByte: 1, endByte: 2, newText: "X" }] }
        wrap := { code: "wrap", HasFix: true, fixable: "auto",
            fixes: [{ startByte: 0, endByte: 0, newText: "(" },
                    { startByte: 1, endByte: 3, newText: ")" }] }
        fixed := FixToFixpoint(_Utf8("abc"), [swap, wrap], (*) => [])
        _Assert(_Text(fixed.source) == "aXc", "source is " _Text(fixed.source))
        _Assert(fixed.fixed.Length == 1 && fixed.fixed[1] == swap, "only swap was fixed")
    }
    cases["fix: edits are applied front to back whatever order they arrive in"] := () {
        late  := { code: "late", HasFix: true, fixable: "auto",
            fixes: [{ startByte: 2, endByte: 3, newText: "C" }] }
        early := { code: "early", HasFix: true, fixable: "auto",
            fixes: [{ startByte: 0, endByte: 1, newText: "AA" }] }
        fixed := FixToFixpoint(_Utf8("abc"), [late, early], (*) => [])
        _Assert(_Text(fixed.source) == "AAbC", "source is " _Text(fixed.source))
        _Assert(fixed.fixed.Length == 2, "both fixed")
    }
    cases["fix: lints that undo each other stop at the cap"] := () {
        ab := _ReplaceFirst("a", "b"), ba := _ReplaceFirst("b", "a")
        lint := (source) => ab(source).Length ? ab(source) : ba(source)
        source := _Utf8("a")
        fixed := FixToFixpoint(source, lint(source), lint)
        _Assert(!fixed.converged, "not converged")
        _Assert(fixed.passes == 10, "passes is " fixed.passes)
        ; The findings must describe the source that comes back, not an earlier pass
        fix := fixed.diagnostics[1].fixes[1]
        _Assert(fix.newText != _Text(fixed.source), "diagnostics are stale")
    }

    cases["run: relinting a file replaces its result in place"] := () {
        run := LintRun(Config.Default(_FakeRegistry(), DEFAULT_TARGET))
        run.AddFile("C:\x\a.ahk", SourceText(_Utf8("a")), [1, 2])
        run.AddFile("C:\x\b.ahk", SourceText(_Utf8("b")), [3])
        replaced := run.AddFile("c:\X\A.ahk", SourceText(_Utf8("a2")), [])
        _Assert(run.FileCount == 2, "FileCount is " run.FileCount)
        _Assert(run.results[1] == replaced, "kept its place")
        _Assert(run.DiagnosticCount == 1, "DiagnosticCount is " run.DiagnosticCount)
        _Assert(run.Find("C:\x\a.ahk") == replaced, "found by path, whatever the case")
    }
    cases["run: a removed file leaves the run"] := () {
        run := LintRun(Config.Default(_FakeRegistry(), DEFAULT_TARGET))
        run.AddFile("C:\x\a.ahk", SourceText(_Utf8("a")), [1])
        kept := run.AddError("C:\x\b.ahk", Error("boom"))
        _Assert(run.Remove("C:\x\a.ahk"), "removed")
        _Assert(!run.Remove("C:\x\a.ahk"), "nothing left to remove")
        _Assert(run.FileCount == 1 && run.results[1] == kept, "only b is left")
        _Assert(run.Find("C:\x\a.ahk") == "", "no longer found")
    }
    cases["source: Matches compares bytes"] := () {
        source := SourceText(_Utf8("x := 1"))
        _Assert(source.Matches(_Utf8("x := 1")), "same bytes")
        _Assert(!source.Matches(_Utf8("x := 2")), "same size, different bytes")
        _Assert(!source.Matches(_Utf8("x := 10")), "different size")
    }

    cases["scopes: assigning makes a local, reading reaches for a global"] := () {
        scopes := _Scopes("x := 1, y := 2`nF() {`n    x := 3`n    return y`n}`n")
        fn := scopes.all[2]
        _Assert(scopes.root.Lookup("x").writes.Length == 1, "the global x has one write")
        _Assert(fn.Lookup("x").kind == "local" && fn.Lookup("x").writes.Length == 1, "F has its own x")
        _Assert(fn.OwnerOf("y") == scopes.root, "y in F is the global")
        _Assert(scopes.root.Lookup("y").reads.Length == 1, "the read in F is recorded on the global")
        _Assert(scopes.root.Lookup("f").kind == "function", "names are case-insensitive")
    }
    cases["scopes: a global declaration redirects assignments"] := () {
        scopes := _Scopes("F() {`n    global x, y := 1`n    x := 2`n}`nG() {`n    global`n    z := 3`n}`n")
        _Assert(scopes.all[2].variables.Count == 0, "F owns nothing")
        _Assert(scopes.root.Lookup("x").writes.Length == 1, "x written through the declaration")
        _Assert(scopes.root.Lookup("y").writes.Length == 1, "y initialized by the declaration")
        _Assert(scopes.root.Lookup("z").writes.Length == 1, "assume-global")
    }
    cases["scopes: a nested function shares what its outer function assigns"] := () {
        ; `shared` is assigned by Outer after Inner is declared; `own` is only read by Outer
        code := "Outer() {`n    Inner() {`n        shared := 1`n        own := 2`n    }`n"
            . "    shared := 3`n    return own`n}`n"
        scopes := _Scopes(code)
        outer := scopes.all[2], inner := scopes.all[3]
        _Assert(inner.OwnerOf("shared") == outer, "shared belongs to Outer")
        _Assert(outer.Lookup("shared").writes.Length == 2, "both assignments are recorded on it")
        _Assert(inner.OwnerOf("own") == inner, "own is local to Inner")
        _Assert(outer.OwnerOf("own") == scopes.root, "Outer's own is a global")
        _Assert(outer.Lookup("Inner").kind == "function", "Inner is declared in Outer")
    }
    cases["scopes: a method doesn't capture"] := () {
        scopes := _Scopes("x := 1`nclass C {`n    M(p) {`n        x := 2`n        return this`n    }`n}`n")
        method := scopes.all[2]
        _Assert(method.OwnerOf("x") == method, "x is local to M")
        _Assert(method.Lookup("p").kind == "param", "p is a parameter")
        _Assert(method.Lookup("this").kind == "implicit", "this is implicit")
        _Assert(scopes.root.Lookup("C").kind == "class", "C is declared")
        _Assert(!scopes.root.Lookup("M"), "a method name is not a variable")
    }
    cases["scopes: writes without a value expression"] := () {
        code := "a := 1`na .= 2`nb++`nF(&c)`nfor d, e in arr`n    f := obj.g`n"
        root := _Scopes(code).root
        _Assert(root.Lookup("a").writes.Length == 2, "a has two writes")
        _Assert(root.Lookup("a").writes[1].value.type == "integer_literal", "a := 1 has a value")
        _Assert(root.Lookup("a").writes[2].value == "", "a .= 2 has none")
        _Assert(root.Lookup("a").reads.Length == 1, "a .= 2 also reads a")
        for name in ["b", "c", "d", "e"]
            _Assert(root.Lookup(name).writes.Length == 1 && root.Lookup(name).writes[1].value == "", name)
        _Assert(!root.Lookup("g"), "a property name is not a variable")
        _Assert(root.Lookup("arr").reads.Length == 1, "arr is read")
    }
    cases["scopes: dynamic references taint the enclosing scopes"] := () {
        scopes := _Scopes("F() {`n    %name% := 1`n}`nG() {`n    return obj.%name%`n}`n")
        _Assert(scopes.all[2].hasDynamicRefs && scopes.root.hasDynamicRefs, "F and the global scope")
        _Assert(!scopes.all[3].hasDynamicRefs, "a dynamic property name is not a variable reference")
    }
    cases["scopes: imports are declared"] := () {
        root := _Scopes('#Import "./a.ahk" { Foo, Bar as Baz }`n#Import "./b.ahk" as B`n#Import Mod`n').root
        for name in ["Foo", "Baz", "B", "Mod"]
            _Assert(root.Lookup(name) && root.Lookup(name).kind == "import", name)
        _Assert(!root.Lookup("Bar"), "an aliased export isn't bound under its own name")
    }
    cases["scopes: local and static stay local in an assume-global function"] := () {
        scopes := _Scopes("F() {`n    global`n    local a := 1`n    static b := 2`n    c := 3`n}`n")
        fn := scopes.all[2]
        _Assert(fn.assumeGlobal, "F is assume-global")
        _Assert(fn.OwnerOf("a") == fn && fn.OwnerOf("b") == fn, "a and b belong to F")
        _Assert(fn.OwnerOf("c") == scopes.root, "c is a global")
    }
    cases["scopes: a function nested in an assume-global one assigns globals"] := () {
        code := "Outer() {`n    global`n    local own := 1`n    Inner() {`n        own := 2, g := 3`n    }`n}`n"
        scopes := _Scopes(code)
        outer := scopes.all[2], inner := scopes.all[3]
        _Assert(inner.OwnerOf("g") == scopes.root, "g is a global")
        _Assert(inner.OwnerOf("own") == outer, "own is Outer's local")
    }
    cases["scopes: a static nested function only sees static variables"] := () {
        code := "Outer() {`n    x := 1`n    static s := 2`n    static Inner() {`n        return x + s`n    }`n"
            . "    y := 3`n    static Assigns() {`n        y := 4`n    }`n}`n"
        scopes := _Scopes(code)
        outer := scopes.all[2], inner := scopes.all[3], assigns := scopes.all[4]
        _Assert(inner.isStatic, "Inner is static")
        _Assert(inner.OwnerOf("x") == scopes.root, "x in Inner is not Outer's")
        _Assert(inner.OwnerOf("s") == outer, "s is Outer's static")
        _Assert(assigns.OwnerOf("y") == assigns, "y in Assigns is its own")
        _Assert(outer.Lookup("x").reads.Length == 0, "Outer's x is never read")
    }
    cases["scopes: a static function sees an assume-static function's variables"] := () {
        scopes := _Scopes("Outer() {`n    static`n    x := 1`n    static Inner() => x`n}`n")
        _Assert(scopes.all[3].OwnerOf("x") == scopes.all[2], "x is Outer's")
    }

    return cases
}
