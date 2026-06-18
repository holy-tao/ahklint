/************************************************************************
 * Builds the Hugo docs site content by merging each lint's static `meta`
 * with its hand-written sibling .md prose. One page per lint is written to
 *   site/content/lints/<category>/<id>.md
 * with front-matter pinning the public URL to /lints/<id>/
 *
 * `meta` can only be read by running AHK, so this imports the generated
 * barrel (lints/all.ahk) for ALL_LINTS. Importing a class does not call its
 * __New, so no tree-sitter instantiation happens here.
 *
 * Generated pages are not committed (.gitignore); CI regenerates them before
 * invoking `hugo`. Run `barrel.ahk` first so ALL_LINTS is current.
 ***********************************************************************/

#Requires AutoHotkey v2.1-alpha.30 64-bit

#Include "./errshim.ahk"
#Import "../lints/all.ahk" { ALL_LINTS }

stdout := FileOpen("*", "w", "UTF-8")

root       := A_ScriptDir "\.."
lintsDir   := root "\lints"
contentDir := root "\site\content\lints"

; Start from a clean slate so a removed/renamed lint leaves no orphan page, but
; keep the hand-written _index.md: only the generated category folders are wiped.
if DirExist(contentDir) {
    loop files contentDir "\*", "D"
        DirDelete(A_LoopFileFullPath, true)
} else {
    DirCreate(contentDir)
}

count      := 0
categories := Map()   ; category -> true, so each section _index.md is written once
for cls in ALL_LINTS {
    meta      := cls.meta
    className := cls.Prototype.__Class

    mdPath := FindSibling(lintsDir, className)
    if !mdPath
        throw Error(Format('lint "{1}" ({2}) has no sibling doc', meta.id, className),, className ".md")

    prose := FileRead(mdPath, "UTF-8")

    ; Gate: every lint must ship at least one example demonstrating it firing,
    ; i.e. a `;~ <id>` marker (the same markers the test harness asserts on).
    if !RegExMatch(prose, ";~\s+" meta.id "(?!\S)")
        throw Error(Format('{1} has no `;~ {2}` example', className ".md", meta.id))

    outDir := contentDir "\" meta.category
    DirCreate(outDir)

    ; A section _index.md turns the category folder into a sidebar group in the
    ; hugo-book theme (without it the pages render ungrouped). Write it once.
    if !categories.Has(meta.category) {
        categories[meta.category] := true
        WriteSectionIndex(outDir, meta.category)
    }

    outFile := FileOpen(outDir "\" meta.id ".md", "w", "UTF-8")
    outFile.Write(BuildPage(meta, prose))
    outFile.Close()

    stdout.WriteLine(Format("  {1} -> lints/{2}/{3}.md", className, meta.category, meta.id))
    count++
}

stdout.WriteLine(Format("Compiled {1} lint doc page(s)", count))
stdout.Close()
ExitApp(0)

/**
 * Locate a lint's sibling doc by class name (filenames match class names,
 * enforced by barrel.ahk / CONTRIBUTING.md). Returns "" if none exists.
 */
FindSibling(lintsDir, className) {
    loop files lintsDir "\*.md", "FR"
        if A_LoopFileName == className ".md"
            return A_LoopFileFullPath
    return ""
}

/**
 * Write a hugo-book section page so the category folder shows as a sidebar
 * group. Title-cased category name; collapsed sections keep the nav tidy.
 */
WriteSectionIndex(dir, category) {
    title := StrUpper(SubStr(category, 1, 1)) SubStr(category, 2)
    idx := FileOpen(dir "\_index.md", "w", "UTF-8")
    idx.Write("---`ntitle: " title "`nbookCollapseSection: false`n---`n")
    idx.Close()
}

/**
 * Assemble one Hugo content page: front-matter, an H1, a one-row info table
 * from `meta`, the prose (with test markers stripped), then a "See also" list
 * from meta.references.
 */
BuildPage(meta, prose) {
    fm := "---`n"
        . 'title: "' StrReplace(meta.title, '"', '\"') '"`n'
        . "url: /lints/" meta.id "/`n"
        . "---`n`n"

    ; Horizontal table: the header row carries the field names (no awkward empty
    ; header) and the single value row spans the page width.
    body := "# " meta.title "`n`n"
          . "| ID | Category | Severity | Fixable | Versions | Recommended |`n"
          . "|----|----------|----------|---------|----------|-------------|`n"
          . Format("| ``{1}`` | {2} | {3} | {4} | ``{5}`` | {6} |`n`n",
                meta.id, meta.category, meta.severity, meta.fixable,
                meta.versions, meta.recommended ? "yes" : "no")
          . RTrim(StripTestMarkers(prose), "`r`n") "`n"

    if meta.references.Length {
        body .= "`n## See also`n`n"
        for ref in meta.references
            body .= "- <" ref ">`n"
    }

    return fm body
}

/**
 * Strip inline `;~ <id>` test markers from example code before publishing. The
 * markers drive the test harness (they must stay in the source .md) but are
 * noise in the rendered docs. Removes the marker through end of line, leaving
 * the surrounding AHK intact (`goto label   ;~ no-goto` -> `goto label`).
 */
StripTestMarkers(prose) => RegExReplace(prose, "m)[ \t]*;~[ \t].*$", "")
