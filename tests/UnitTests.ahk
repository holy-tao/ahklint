#Requires AutoHotkey v2.0

; Hand-written unit tests for the config/version machinery - the stateful,
; non-doc-derived logic that the example fixtures (RunTests.ahk) can't cover.
; Recorded into the same JUnit writer so they share junit.xml and the exit code.

#Import "../Config.ahk" { Config }
#Import "../Linter.ahk" { DEFAULT_TARGET }

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

_FakeRegistry() => [_FakeRecommended, _FakeOptional, _FakeNewOnly]

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

    return cases
}
