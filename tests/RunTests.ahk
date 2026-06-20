#Requires AutoHotkey v2.0

#Include "../build/errshim.ahk"

#Import "./YUnit/JUnit.ahk" { YUnitJUnit as JUnit }

#Import "../AutoHotkeyLang.ahk" { AutoHotkeyLang }
#Import "../Linter.ahk" { Linter, DEFAULT_TARGET }
#Import "../lints/all.ahk" { ALL_LINTS }

#Include "./UnitTests.ahk"

#DllLoad "../bin/tree-sitter-autohotkey.dll"
#DllLoad "../bin/tree-sitter.dll"

lang := AutoHotkeyLang()
stdout := FileOpen("*", "w", "UTF-8")

junitWriter := JUnit(0)

loop files "../lints/*.md", "fr" {
	TestFile(A_LoopFileFullPath, junitWriter, lang)
}

RunUnitTests(junitWriter)

stdout.WriteLine(Format("`n{1} test(s): {2} passed, {3} failed",
	junitWriter.tests.overall, junitWriter.tests.pass, junitWriter.tests.fail))
_ := stdout.Handle

; Drop the last reference so __Delete flushes junit.xml before we exit, then
; signal pass/fail to CI through the process exit code.
failed := junitWriter.tests.fail
junitWriter := ""
ExitApp(failed ? 1 : 0)

/**
 * Scan one lint doc for fenced AutoHotkey examples and turn each into a test
 * case. Every block is linted in isolation; the diagnostics it produces must
 * match the `;~ <lint-id>` markers in the block exactly - no more, no less.
 *
 * @param filepath absolute path to the .md file
 * @param writer the JUnit writer to record results into
 * @param lang the tree-sitter language to lint with
 */
TestFile(filepath, writer, lang) {
	static FENCE_START_PAT := "i)^``````\s*autohotkey\s+test"
	static LINT_ID_PAT     := ";~\s+(?<lint>\S+)"

	relPath := writer.StripPathToRelative(filepath)
	stdout.WriteLine("Scanning " relPath " ...")

	testFile := FileOpen(filepath, "r")

	inCodeBlock    := false
	acc            := ""
	blockline      := 0   ; 1-based line within the current block (matches diag rows)
	blockStartLine := 0   ; line of the opening fence, for annotations
	fileLineNum    := 0
	expectedLints  := []  ; [{ lint: String, line: Int }]

	loop {
		line := testFile.ReadLine()
		fileLineNum++

		if !inCodeBlock && RegExMatch(line, FENCE_START_PAT) {
			inCodeBlock    := true
			blockStartLine := fileLineNum
		}
		else if inCodeBlock {
			if InStr(line, "``````") == 1 {
				inCodeBlock := false
				RunBlock(writer, lang, relPath, filepath, blockStartLine, acc, expectedLints)

				acc           := ""
				expectedLints := []
				blockline     := 0
			}
			else {
				blockline++
				acc .= line "`r`n"
				if RegExMatch(line, LINT_ID_PAT, &match)
					expectedLints.Push({ lint: match["lint"], line: blockline })
			}
		}
	}
	until testFile.AtEOF

	_ := stdout.Handle	; accessing the handle flushes the write buffer
}

/**
 * Lint a single block and record one test case. A failure lists every mismatch
 * between the diagnostics that fired and the markers in the block.
 */
RunBlock(writer, lang, relPath, filepath, startLine, code, expectedLints) {
	testName := "block@line" startLine
	t0 := A_TickCount

	try {
		diagnostics := RunLints(lang, code)
	} catch as e {
		Fail(writer, relPath, testName, filepath, startLine,
			"linter threw while checking block: " e.message, e.stack)
		stdout.WriteLine(Format("  🚨 ERROR {1}: {2} ({3})", testName, e.message, e.extra))
		stdout.WriteLine("    " StrReplace(e.Stack, "`n", "`n    "))
		return
	}

	failures := CompareDiagnostics(diagnostics, expectedLints, startLine)
	time := (A_TickCount - t0) / 1000

	if !failures.Length {
		writer.Update(relPath, testName, true, time)
		stdout.WriteLine(Format("  ok   {1}", testName))
		return
	}

	msg := ""
	for f in failures
		msg .= "- " f "`n"
	Fail(writer, relPath, testName, filepath, startLine, RTrim(msg, "`n"), "", time)

	stdout.WriteLine(Format("  ❌ FAIL {1} ({2} mismatch(es))", testName, failures.Length))
	for f in failures
		stdout.WriteLine("    " f)
}

/**
 * Parse a snippet and run the lints over it. The source must be a real Buffer:
 * tree-sitter reads bytes through it and the Tree holds it alive, so a
 * buffer-like wrapper risks the backing memory being collected.
 */
RunLints(lang, code) {
	size := StrPut(code, "UTF-8")	; bytes including the null terminator
	buf  := Buffer(size)
	StrPut(code, buf, "UTF-8")
	buf.Size -= 1					; drop the terminator from the parsed range

	cfg := Config.Default(ALL_LINTS, "")
	DefineProp(cfg, "UNIT_TEST_RUN", { value: true })

	return Linter(lang, buf, cfg).Run()
}

/**
 * Compare fired diagnostics against the expected markers. Returns a list of
 * human-readable mismatch descriptions (empty == the block passed).
 *
 * Matching is on (lint id, line within block). Lines are reported as absolute
 * .md line numbers so failures point straight at the file.
 */
CompareDiagnostics(diagnostics, expectedLints, startLine) {
	failures := []
	matched  := Map()	; index into expectedLints -> already satisfied

	for diag in diagnostics {
		diagLine := diag.start.row + 1
		hit := false
		for i, exp in expectedLints {
			if !matched.Has(i) && exp.lint == diag.code && exp.line == diagLine {
				matched[i] := true
				hit := true
				break
			}
		}
		if !hit
			failures.Push(Format('unexpected "{1}" fired (md line {2})',
				diag.code, startLine + diagLine))
	}

	for i, exp in expectedLints {
		if !matched.Has(i)
			failures.Push(Format('expected "{1}" (md line {2}) but it did not fire',
				exp.lint, startLine + exp.line))
	}

	return failures
}

/**
 * Record a failing test case. Points the JUnit <failure> file/line at the .md
 * so CI annotations land in the right place.
 */
Fail(writer, category, testName, filepath, line, message, stack := "", time := 0) {
	err := Error(message)
	err.File  := filepath
	err.Line  := line
	err.Stack := stack
	writer.Update(category, testName, err, time)
}
