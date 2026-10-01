#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"

; How many times FixToFixpoint will apply fixes and relint before giving up. Only a
; pair of lints undoing each other's fixes should ever get near it.
MAX_FIX_PASSES := 10

/**
 * Move `length` bytes from `source` to `destination`
 * @returns {void} nothing
 */
MoveMemory(source, destination, length) =>
    DllCall("RtlMoveMemory", IntPtr, destination, IntPtr, source, UInt32, length)

/**
 * True if `a` belongs after `b` in a front-to-back list of patches.
 */
SortsAfter(a, b) =>
    a.startByte > b.startByte || (a.startByte == b.startByte && a.endByte > b.endByte)

/**
 * Insert `patch` into `patches`, keeping it sorted front to back, unless it would
 * overlap a patch already there.
 *
 * @param {Array<Fix>} patches non-overlapping patches, sorted by `startByte` ascending
 * @param {Fix} patch the patch to insert
 * @returns {Boolean} true if the patch was inserted
 */
InsertPatch(patches, patch) {
    ; Findings arrive roughly in file order, so the slot is usually at the end
    i := patches.Length
    while i > 0 && SortsAfter(patches[i], patch)
        i--

    ; The list has no overlaps, so only the two neighbors can collide
    if i > 0 && patch.startByte < patches[i].endByte
        return false
    if i < patches.Length && patches[i + 1].startByte < patch.endByte
        return false

    patches.InsertAt(i + 1, patch)
    return true
}

/**
 * Choose the fixes in `diagnostics` to apply in one pass. A finding's fix is taken
 * whole or not at all: if any of its edits overlaps one already chosen, the finding
 * is left for a later pass of FixToFixpoint, so no byte is edited twice and no fix
 * is half-applied.
 *
 * @param {Array<Diagnostic>} diagnostics the findings to gather fixes for
 * @param {Boolean} includeSuggestions if true, also apply suggestions
 * @returns {Object} `diagnostics`, the findings whose fixes were chosen, and
 *          `patches`, their edits, non-overlapping and sorted by `startByte` ascending
 */
SelectFixes(diagnostics, includeSuggestions) {
    chosen := [], patches := []

    for diag in diagnostics {
        if !diag.HasFix
            continue
        if !(diag.fixable == "auto" || (includeSuggestions && diag.fixable == "suggestion"))
            continue

        inserted := []
        for patch in diag.fixes {
            if !InsertPatch(patches, patch)
                break
            inserted.Push(patch)
        }

        if inserted.Length == diag.fixes.Length {
            chosen.Push(diag)
            continue
        }

        ; Take back the edits that did fit
        for patch in inserted {
            for candidate in patches {
                if candidate == patch {
                    patches.RemoveAt(A_Index)
                    break
                }
            }
        }
    }

    return { diagnostics: chosen, patches: patches }
}

/**
 * Encode `text` into a new buffer with no null terminator.
 *
 * @param {String} text the text to encode
 * @param {String} encoding the encoding to use
 * @returns {Buffer} the encoded bytes
 */
Encode(text, encoding) {
    if text == ""
        return Buffer(0)

    ; StrPut's size includes the terminator; write it into a scratch buffer and trim
    terminated := Buffer(StrPut(text, encoding))
    StrPut(text, terminated, encoding)
    terminated.Size -= (encoding = "UTF-16" || encoding = "CP1200") ? 2 : 1
    return terminated
}

/**
 * Apply `patches` to `src`.
 *
 * The source is never edited in place. The output is built front to back in a new
 * buffer: the untouched bytes between fixes are copied, and each fix's text is written
 * where its byte range was.
 *
 * TODO: Don't hardcode utf-8
 *
 * @param {Buffer} src the source code to patch
 * @param {Array<Fix>} patches non-overlapping edits, sorted by `startByte` ascending
 * @returns {Buffer} a buffer containing the patched source code
 */
ApplyPatches(src, patches) {
    encoded := patches.Map(patch => Encode(patch.newText, "UTF-8"))

    size := src.Size
    for patch in patches
        size += encoded[A_Index].Size - (patch.endByte - patch.startByte)

    fixed := Buffer(size)
    readPos := 0, writePos := 0
    for patch in patches {
        ; Unchanged bytes up to this fix
        gap := patch.startByte - readPos
        MoveMemory(src.Ptr + readPos, fixed.Ptr + writePos, gap)
        writePos += gap

        text := encoded[A_Index]
        MoveMemory(text.Ptr, fixed.Ptr + writePos, text.Size)
        writePos += text.Size

        readPos := patch.endByte
    }

    ; Everything after the last fix
    MoveMemory(src.Ptr + readPos, fixed.Ptr + writePos, src.Size - readPos)
    return fixed
}

/**
 * Apply fixes and relint until there are no more fixes to apply, or until we hit
 * MAX_FIX_PASSES passes. This means all fixes for lints whose `fixable` is `"auto"`,
 * plus suggestions if `includeSuggestions` is truthy.
 *
 * @param {Buffer} source the source code to fix
 * @param {Array<Diagnostic>} diagnostics the findings in `source`
 * @param {(Buffer) => Array<Diagnostic>} lint lints a patched buffer
 * @param {Boolean} includeSuggestions if true, also apply suggestions
 * @returns {Object} `source` and `diagnostics` after the last pass, `fixed` (the
 *          findings whose fixes were applied; their spans point into the buffer of
 *          the pass that found them, not into `source`), `passes` (0 when nothing
 *          was fixed, in which case `source` is the buffer passed in), and
 *          `converged` (false when fixes were still pending at the cap)
 */
export FixToFixpoint(source, diagnostics, lint, includeSuggestions := false) {
    fixed := []
    passes := 0
    loop {
        selected := SelectFixes(diagnostics, includeSuggestions)
        pending := selected.patches.Length > 0
        if !pending || passes >= MAX_FIX_PASSES
            break

        source := ApplyPatches(source, selected.patches)
        fixed.Push(selected.diagnostics*)
        diagnostics := lint(source)
        passes++
    }

    return { source: source, diagnostics: diagnostics, fixed: fixed, passes: passes,
        converged: !pending }
}
