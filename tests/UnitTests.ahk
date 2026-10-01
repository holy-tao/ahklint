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
    Config(Map("lints", Map("fake-options", ["warn", opts])), _FakeRegistry(), "2.0")

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

    cfg := Config(Map("extends", "all"), ALL_LINTS, "2.1-alpha.30")
    run := LintRun(cfg)
    run.AddFile(root "\a.ahk", SourceText(buf), Linter(AutoHotkeyLang(), buf, cfg).Run())
    run.AddError(root "\b.ahk", Error("boom"))

    return log := JSON.Parse(JSON.Dump(CreateSarif(run, root)))
}

/** The `no-cdecl` result from _SarifLog. */
_SarifCdeclResult() {
    for result in _SarifLog()["runs"][1]["results"]
        if result["ruleId"] == "no-cdecl"
            return result
    throw Error("no no-cdecl result")
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
        c := Config(Map("extends", "all"), _FakeRegistry(), "2.0")
        _Assert(c.SeverityFor("fake-opt") == "warn", "opt enabled under all")
    }
    cases["config: extends none"] := () {
        c := Config(Map("extends", "none"), _FakeRegistry(), "2.0")
        _Assert(c.SeverityFor("fake-rec") == "off", "rec off under none")
    }

    cases["config: enable optional via lints map"] := () {
        c := Config(Map("lints", Map("fake-opt", "error")), _FakeRegistry(), "2.0")
        _Assert(c.SeverityFor("fake-opt") == "error", "opt overridden to error")
        _Assert(c.SeverityFor("fake-rec") == "warn",  "rec still on from preset")
    }
    cases["config: disable recommended via lints map"] := () {
        c := Config(Map("lints", Map("fake-rec", "off")), _FakeRegistry(), "2.0")
        _Assert(c.SeverityFor("fake-rec") == "off", "rec silenced")
    }
    cases["config: tuple severity form"] := () {
        c := Config(Map("lints", Map("fake-rec", ["error", Map()])), _FakeRegistry(), "2.0")
        _Assert(c.SeverityFor("fake-rec") == "error", "tuple severity parsed")
    }

    cases["config: unknown lint id throws"] := () =>
        _Throws(() => Config(Map("lints", Map("nope", "warn")), _FakeRegistry(), "2.0"))
    cases["config: unknown extends throws"] := () =>
        _Throws(() => Config(Map("extends", "everything"), _FakeRegistry(), "2.0"))
    cases["config: invalid severity throws"] := () =>
        _Throws(() => Config(Map("lints", Map("fake-rec", "loud")), _FakeRegistry(), "2.0"))
    cases["config: severity is case-insensitive"] := () {
        c := Config(Map("lints", Map("fake-rec", "Error")), _FakeRegistry(), "2.0")
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
        _Throws(() => Config(Map("lints", Map("fake-options", ["warn", Map(), 1])), _FakeRegistry(), "2.0"))

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

    return cases
}
