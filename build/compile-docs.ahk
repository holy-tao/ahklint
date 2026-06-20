/************************************************************************
 * Builds the Hugo docs site content by merging each lint's static `meta`
 * with its hand-written sibling .md prose. One page per lint is written to
 *   site/content/lints/<category>/<id>.md
 * with front-matter pinning the public URL to /lints/<id>/
 *
 * Also generates index pages:
 *   site/content/lints/_index.md           - all lints grouped by category
 *   site/content/lints/<category>/_index.md - per-category lint list
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

; Start from a clean slate so a removed/renamed lint leaves no orphan page.
; Delete all subdirectories and the generated top-level _index.md.
if DirExist(contentDir) {
    loop files contentDir "\*", "D"
        DirDelete(A_LoopFileFullPath, true)
    if FileExist(contentDir "\_index.md")
        FileDelete(contentDir "\_index.md")
} else {
    DirCreate(contentDir)
}

count      := 0
byCategory := Map()   ; category -> Array of meta objects, preserves insertion order

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

    if !byCategory.Has(meta.category)
        byCategory[meta.category] := []
    byCategory[meta.category].Push(meta)

    outFile := FileOpen(outDir "\" meta.id ".md", "w", "UTF-8")
    outFile.Write(BuildPage(meta, prose))
    outFile.Close()

    stdout.WriteLine(Format("  {1} -> lints/{2}/{3}.md", className, meta.category, meta.id))
    count++
}

; Write per-category _index.md pages and the root _index.md
for category, metas in byCategory
    WriteCategoryIndex(contentDir "\" category, category, metas)

WriteRootIndex(contentDir, byCategory)

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
 * Standard column header + divider for the lint summary table.
 */
LintTableHeader() => "
(ltrim rtrim
    | ID | Title | Severity | Fixable | Versions | Recommended |
    |----|-------|----------|---------|----------|-------------|
)"

/**
 * One data row for the lint summary table. Links the ID to its docs page.
 */
LintTableRow(meta) =>
    Format("| [``{1}``](/ahklint/lints/{1}/) | {2} | {3} | {4} | ``{5}`` | {6} |`n",
        meta.id, meta.title, meta.severity, meta.fixable,
        meta.versions, meta.recommended ? "yes" : "no")

/**
 * Write the per-category _index.md: front-matter + a table of every lint
 * in that category.
 */
WriteCategoryIndex(dir, category, metas) {
    body := Format("
    (comments ltrim rtrim
        ---
        title: {1}
        bookCollapseSection: false
        ---

        # {1}   ; YAML frontmatter title doesn't work for indexes for some reason?

        {2}
        
    )", StrTitle(category), LintTableHeader())
    for meta in metas
        body .= LintTableRow(meta)
    idx := FileOpen(dir "\_index.md", "w", "UTF-8")
    idx.Write(body)
    idx.Close()
}

/**
 * Write site/content/lints/_index.md: intro + one section per category, each
 * with a summary table, so the top-level Lints page is a one-stop reference.
 */
WriteRootIndex(contentDir, byCategory) {
    body := Format("
    (comments ltrim rtrim
        ---
        title: Lints
        weight: 1
        bookCollapseSection: false
        bookFlatSection: false
        ---

        # Lints ; YAML frontmatter title doesn't work for indexes for some reason?

        Every lint included in ``ahklint``, grouped by category.\

    )")
    for category, metas in byCategory {
        title := StrUpper(SubStr(category, 1, 1)) SubStr(category, 2)
        body .= "`n## " title "`n`n" . LintTableHeader() "`n"
        for meta in metas
            body .= LintTableRow(meta)
    }
    idx := FileOpen(contentDir "\_index.md", "w", "UTF-8")
    idx.Write(body)
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
