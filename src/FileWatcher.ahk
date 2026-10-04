#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "./FileSystemWatcher" { FileSystemWatcher }
#Import "utils/Console" { Console }
#Import "./Colors" { Gray, IsEnabled as AnsiEnabled }

; How long to wait after a change before linting. One save is several
; notifications, and an editor that saves through a temp file renames on top.
DEBOUNCE_MS := 100

/**
 * `FileWatcher` wraps the more-general `FileSystemWatcher` and filters to applicable
 * paths, re-running lints as necessary.
 *
 * Notifications arrive on FileSystemWatcher's polling thread and can interrupt a
 * lint that is under way, so they only note which paths are dirty and (re)start a
 * timer. The linting happens when the timer fires.
 */
export class FileWatcher {
    /**
     * @param {LintSession} session the session to keep up to date, already run once
     * @param {String} root absolute path of the file or directory it linted
     * @param {File} out where to write the status line
     */
    __New(session, root, out) {
        this._session := session
        this._root := root
        this._out := out

        ; A directory is watched whole. A file is watched through its directory,
        ; since that is the only thing Windows can watch.
        if DirExist(root) {
            this._dir := RTrim(root, "\")
            this._only := ""
        } else {
            SplitPath(root, &name, &dir)
            this._dir := dir
            this._only := name
        }

        this._dirty := FileWatcher._PathSet()
        this._busy := false
        this._flushTimer := ObjBindMethod(this, "_Flush")

        this._watcher := FileSystemWatcher(this._dir, this._only == "")
        this._watcher.OnEvent((change) => this._OnChange(change))
        this._watcher.Start()

        this._Status()
    }

    static _PathSet() {
        paths := Map()
        paths.CaseSense := "Off"   ; Windows paths are case-insensitive
        return paths
    }

    /**
     * @param {Object} change an event from FileSystemWatcher: an `action` and a
     *        `path` relative to the watched directory
     */
    _OnChange(change) {
        path := this._dir "\" change.path

        if change.action == "OVERFLOW" {
            ; Changes were lost, so look at everything again
            this._dirty[this._root] := true
        }
        else if this._only != "" && change.path = this._only{
            this._dirty[path] := true
        }
        else if change.path ~= "i)\.ahk$" {
            this._dirty[path] := true
        }
        else if change.action != "MODIFIED" && DirExist(path) {
            ; A directory moved or copied in brings files that get no notification
            ; of their own
            this._dirty[path] := true
        }

        ; Always, even with nothing dirty: a removed directory names no files, and
        ; the flush is what notices that results have lost theirs.
        SetTimer(this._flushTimer, -DEBOUNCE_MS)
    }

    _Flush() {
        if this._busy {
            SetTimer(this._flushTimer, -DEBOUNCE_MS)
            return
        }

        this._busy := true
        try {
            dirty := this._dirty
            this._dirty := FileWatcher._PathSet()

            session := this._session
            session.ClearFixed()
            changed := session.Prune()
            for path in dirty {
                if DirExist(path) {
                    loop files path "\*.ahk", "r"
                        changed := session.Refresh(A_LoopFileFullPath) || changed
                } else {
                    changed := session.Refresh(path) || changed
                }
            }

            if changed
                this._Redraw()
        } finally {
            this._busy := false
        }
    }

    _Redraw() {
        ; Erase the screen and home the cursor. Redirected output gets a blank line
        ; instead, so a log stays readable.
        if AnsiEnabled()
            this._out.Write(Console.Escape "[2J" Console.Escape "[H")
        else
            this._out.WriteLine("")

        this._session.Replay()
        this._Status()
    }

    _Status() {
        this._out.WriteLine(Gray(Format("[{1}] Watching {2} for changes. Press Ctrl+C to stop.",
            FormatTime(, "HH:mm:ss"), this._root)))

        _ := this._out.Handle
    }
}
