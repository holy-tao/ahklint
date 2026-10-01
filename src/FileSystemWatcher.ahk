#Requires AutoHotkey v2.1-alpha.30 64-bit
; This particular implementation is heavily inspired by the .NET Windows implementation
; of System.IO.FileSystem.Watcher:
; https://github.com/dotnet/dotnet/blob/b0f34d51fccc69fd334253924abd8d6853fad7aa/src/runtime/src/libraries/System.IO.FileSystem.Watcher/src/System/IO/FileSystemWatcher.Win32.cs#L18
class FileSystemWatcher {
    static FILTER => 0x1 | 0x2 | 0x10 ; Changes to: filename, dirname, last write time
    _directory := ""
    _recursive := true
    _watching := false

    /**
     * Callbacks registered with OnEvent
     * @type {Array<Func>}
     */
    _handlers := []

    /**
     * Directory handle, opened for overlapped I/O
     */
    _hDir := 0

    /**
     * Manual-reset event signalled by the kernel when a pending read completes
     */
    _hEvent := 0

    /**
     * OVERLAPPED struct for the pending ReadDirectoryChangesW call
     * @type {Buffer}
     */
    _overlapped := ""

    /**
     * Receives FILE_NOTIFY_INFORMATION records. Per-instance because the kernel writes into it
     * asynchronously while a read is pending.
     * @type {Buffer}
     */
    _buffer := ""
    _timer := ""

    /**
     * Interval at which to poll for file changes.
     * @type {Integer}
     */
    pollInterval := 250

    /**
     * @param {String} directory the directory to watch
     * @param {Boolean} recursive also watch its subdirectories
     */
    __New(directory, recursive := true) {
        if !DirExist(directory := String(directory))
            throw ValueError("Cannot watch a nonexistent directory", -1, directory)
        this._directory := directory
        this._recursive := !!recursive
    }

    /**
     * Register a function to call with each change, as an object with:
     *
     *   - `action`: "ADDED", "REMOVED", "MODIFIED" or "RENAMED". A rename whose two
     *     halves didn't arrive together comes as "RENAMED_OLD_NAME" and
     *     "RENAMED_NEW_NAME" instead. "OVERFLOW" means changes came faster than
     *     they could be read and some were lost; what changed is unknown.
     *   - `path`: the changed file or directory, relative to the watched directory.
     *     For "RENAMED" this is the new name. Empty for "OVERFLOW".
     *   - `oldPath`: for "RENAMED", the previous name.
     *
     * Callbacks run on the polling timer's thread, which can interrupt whatever
     * the script is in the middle of. Keep them short: note the change and do the
     * work elsewhere.
     *
     * @param {(Object) => Any} callback the function to call
     * @param {Integer} addRemove 1 to add it, 0 to remove it
     */
    OnEvent(callback, addRemove := 1) {
        for handler in this._handlers {
            if handler == callback {
                this._handlers.RemoveAt(A_Index)
                break
            }
        }
        if addRemove
            this._handlers.Push(callback)
    }

    Start() {
        if this._watching
            return

        ; FILE_LIST_DIRECTORY, share read|write|delete, OPEN_EXISTING,
        ; FILE_FLAG_BACKUP_SEMANTICS (required for directories) | FILE_FLAG_OVERLAPPED
        hDir := DllCall("kernel32\CreateFileW",
            "str", this._directory,
            UInt32, 0x1,
            UInt32, 0x7,
            IntPtr, 0,
            UInt32, 3,
            UInt32, 0x02000000 | 0x40000000,
            IntPtr, 0,
            IntPtr)
        if hDir == -1
            throw OSError()

        this._hDir := hDir
        if !this._hEvent := DllCall("kernel32\CreateEventW", IntPtr, 0, Int32, true, Int32, false, IntPtr, 0, IntPtr) {
            err := A_LastError
            DllCall("kernel32\CloseHandle", IntPtr, this._hDir)
            this._hDir := 0
            throw OSError(err)
        }

        ; OVERLAPPED: Internal, InternalHigh (ptr), Offset, OffsetHigh (uint), hEvent (ptr)
        this._overlapped := Buffer(A_PtrSize * 3 + 8, 0)
        NumPut("ptr", this._hEvent, this._overlapped, A_PtrSize * 2 + 8)
        this._buffer := Buffer(2 ** 12, 0)
        this._watching := true
        this._BeginRead()
        SetTimer(this._timer := ObjBindMethod(this, "_Poll"), this.pollInterval)
    }

    Stop() {
        if !this._watching
            return

        this._watching := false
        SetTimer(this._timer, 0)

        ; Cancel the pending read and wait for the cancellation to complete before the buffer and
        ; OVERLAPPED go away, otherwise the kernel may write into freed memory
        DllCall("kernel32\CancelIoEx", IntPtr, this._hDir, IntPtr, this._overlapped.Ptr)
        DllCall("kernel32\GetOverlappedResult", IntPtr, this._hDir, IntPtr, this._overlapped.Ptr, "uint*", &bytes := 0, Int32, true) ;@ahklint-ignore os-thread-block
        DllCall("kernel32\CloseHandle", IntPtr, this._hDir)
        DllCall("kernel32\CloseHandle", IntPtr, this._hEvent)
        this._hDir := this._hEvent := 0
    }

    /**
     * Issues an asynchronous ReadDirectoryChangesW call. Returns immediately; `_hEvent` is
     * signalled when changes are available.
     */
    _BeginRead() {
        ok := DllCall("kernel32\ReadDirectoryChangesW",
            IntPtr, this._hDir,
            IntPtr, this._buffer.ptr,
            UInt32, this._buffer.Size,
            Int32, this._recursive,
            UInt32, FileSystemWatcher.FILTER,
            IntPtr, 0,
            IntPtr, this._overlapped.Ptr,
            IntPtr, 0,
            Int32)

        if !ok
            throw OSError()
    }

    /**
     * The actual polling function. This is called on a timer instead of in a sleep loop so
     * that `Watch()` doesn't block the calling thread.
     */
    _Poll() {
        Critical() ; Don't let e.g. a tray menu Stop() interrupt us mid-parse
        if !this._watching
            return

        ok := DllCall("kernel32\GetOverlappedResult",
            IntPtr, this._hDir,
            IntPtr, this._overlapped.Ptr,
            "uint*", &bytes := 0,
            Int32, false,
            Int32)

        if !ok {
            ; ERROR_IO_INCOMPLETE means no changes yet, and the read is still pending
            if A_LastError == 996
                return

            ; Anything else won't get better by asking again, e.g. the directory
            ; has been deleted. Stop rather than throw on every tick.
            err := OSError()
            this.Stop()
            throw err
        }

        events := []
        if bytes == 0 {
            ; The buffer overflowed and the kernel discarded the changes
            events.Push({ action: "OVERFLOW", path: "" })
        }
        else {
            addr := this._buffer.Ptr
            loop {
                next := ReadNotifyInfo(addr, &action := "", &path := "")
                event := { action: action, path: path }

                ; If we see a RENAMED_OLD_NAME, expect an immediate RENAMED_NEW_NAME which we can
                ; compose into a much nicer "Renamed" event. If we don't see one, just fire the
                ; events as usual.
                if action = "RENAMED_OLD_NAME" && next != 0 {
                    next2 := ReadNotifyInfo(addr + next, &action2 := "", &path2 := "")
                    if action2 == "RENAMED_NEW_NAME" {
                        event := { action: "RENAMED", path: path2, oldPath: path }
                        addr += next, next := next2
                    }
                }

                events.Push(event)

                if next == 0
                    break
                addr += next
            }
        }

        ; Only start the next read once the buffer has been fully processed. The events
        ; were copied out of it, so the handlers can run after the kernel has it back.
        this._BeginRead()

        ; The handlers are outside the critical section
        Critical("Off")
        for handler in this._handlers.Clone()
            for event in events
                handler(event)

        /**
         * Read a `FILE_NOTIFY_INFORMATION` struct off of `addr` and return its the offset to the next
         * See https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-file_notify_information
         */
        ReadNotifyInfo(addr, &action, &path) {
            static actions := ["ADDED", "REMOVED", "MODIFIED", "RENAMED_OLD_NAME", "RENAMED_NEW_NAME"]
            action := actions[NumGet(addr + 4, "uint")]
            path := StrGet(addr + 12, NumGet(addr + 8, "uint") >> 1, "UTF-16")
            return NumGet(addr, "uint")
        }
    }
}
