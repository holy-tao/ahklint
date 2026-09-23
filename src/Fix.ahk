#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"

/**
 * Move `length` bytes from `source` to `destination`
 * @returns {void} nothing
 */
MoveMemory(source, destination, length) =>
    DllCall("RtlMoveMemory", IntPtr, destination, IntPtr, source, UInt32, length)

/**
 * Collect all of the fixes in `result` which can be applied, ordered from the start
 * of the file to the end. A fix that overlaps one before it is dropped, so no byte is
 * edited twice. A later `--fix` pass can pick it up once the first edit is in.
 *
 * @param {FileResult} result the result to gather fixes for
 * @returns {Array<Fix>} non-overlapping fixes, sorted by `startByte` ascending
 */
CollectPatches(result) {
    candidates := result.diagnostics
        .Filter(diag => diag.fixable == "auto" && diag.HasFix)
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
        if deconflicted.length <= 0 || patch.startByte > deconflicted[-1].endByte
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
 * Apply the automatically-applyable fixes identified in `result`. This means all fixes
 * for lints whose `fixable` is `"auto"`.
 *
 * The source is never edited in place. The output is built front to back in a new
 * buffer: the untouched bytes between fixes are copied, and each fix's text is written
 * where its byte range was.
 *
 * TODO: Don't hardcode utf-8
 *
 * @param {FileResult} result the result to apply fixes to
 * @returns {Buffer | String} a buffer containing the patched source code, or "" if there
 *          are no fixes to apply
 */
export ApplyFixes(result) {
    if result.HasError || result.diagnostics.Length == 0
        return ""

    patches := CollectPatches(result)
    if patches.Length == 0
        return ""

    src := result.source._buf
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
