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
 * Collect all of the fixes in `diagnostics` which can be applied, ordered from the
 * start of the file to the end. A fix that overlaps one before it is dropped, so no
 * byte is edited twice. A later pass of FixToFixpoint picks it up once the first edit
 * is in.
 *
 * @param {Array<Diagnostic>} diagnostics the findings to gather fixes for
 * @param {Boolean} includeSuggestions if true, also apply suggestions
 * @returns {Array<Fix>} non-overlapping fixes, sorted by `startByte` ascending
 */
CollectPatches(diagnostics, includeSuggestions) {
    candidates := diagnostics
        .Filter((diag) {
            return diag.HasFix
                && (diag.fixable == "auto" || (includeSuggestions && diag.fixable == "suggestion"))
        })
        .Reduce((flat, current) {
            flat.Push(current.fixes*)
            return flat
        }, [])

    ; Sort front to back, basic insertion sort. Revisit if lint counts get too high (extensions has a
    ; quicksort implementation, but the comparison logic would be a pain to express)
    sorted := []
    for patch in candidates {
        i := sorted.Length
        while i > 0 && (sorted[i].startByte > patch.startByte
                || (sorted[i].startByte == patch.startByte && sorted[i].endByte > patch.endByte))
            i--
        sorted.InsertAt(i + 1, patch)
    }

    ; Remove overlapping patches
    return sorted.Reduce((deconflicted, patch) {
        if deconflicted.length <= 0 || patch.startByte >= deconflicted[-1].endByte
            deconflicted.Push(patch)
        return deconflicted
    }, [])
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
 * Apply the automatically-applyable fixes identified in `diagnostics`. This means all
 * fixes for lints whose `fixable` is `"auto"`, plus suggestions if `includeSuggestions`
 * is truthy.
 *
 * The source is never edited in place. The output is built front to back in a new
 * buffer: the untouched bytes between fixes are copied, and each fix's text is written
 * where its byte range was.
 *
 * TODO: Don't hardcode utf-8
 *
 * @param {Buffer} src the source code the diagnostics were found in
 * @param {Array<Diagnostic>} diagnostics the findings whose fixes to apply
 * @param {Boolean} includeSuggestions if true, also apply suggestions
 * @returns {Buffer | String} a buffer containing the patched source code, or "" if there
 *          are no fixes to apply
 */
export ApplyFixes(src, diagnostics, includeSuggestions := false) {
    if diagnostics.Length == 0
        return ""

    patches := CollectPatches(diagnostics, includeSuggestions)
    if patches.Length == 0
        return ""

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
 * MAX_FIX_PASSES passes.
 *
 * @param {Buffer} source the source code to fix
 * @param {Array<Diagnostic>} diagnostics the findings in `source`
 * @param {(Buffer) => Array<Diagnostic>} lint lints a patched buffer
 * @param {Boolean} includeSuggestions if true, also apply suggestions
 * @returns {Object} `source` and `diagnostics` after the last pass, `passes` (0 when
 *          nothing was fixed, in which case `source` is the buffer passed in), and
 *          `converged` (false when fixes were still pending at the cap)
 */
export FixToFixpoint(source, diagnostics, lint, includeSuggestions := false) {
    passes := 0
    loop {
        fixed := ApplyFixes(source, diagnostics, includeSuggestions)
        if !(fixed is Buffer) || passes >= MAX_FIX_PASSES
            break

        source := fixed
        diagnostics := lint(source)
        passes++
    }

    return { source: source, diagnostics: diagnostics, passes: passes, converged: !(fixed is Buffer) }
}
