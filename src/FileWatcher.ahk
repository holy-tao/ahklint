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
        else if this._only != "" {
            ; A file named on the command line is linted whatever the globs say, and
            ; nothing else in its directory is
            if change.path = this._only
                this._dirty[path] := true
        }
        else if this._Matches(change.path) {
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

    /**
     * Whether a changed path is matches include and exclude globs.
     *
     * @param {String} rel the path relative to the watched directory
     */
    _Matches(rel) {
        ; Globs are matched against the path relative to the root, "/"-separated
        rel := StrReplace(rel, "\", "/")
        SplitPath(rel, , &parent)

        matcher := this._session.matcher
        return matcher.PathMatches(rel) && !matcher._IsBaseExcluded(parent)
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
            matches := ""
            for path in dirty {
                if DirExist(path) {
                    ; Walk from the root like LintAll so the globs see the same relative paths
                    if !IsObject(matches)
                        matches := session.matcher.Matches(this._dir)
                    prefix := RTrim(path, "\") "\"
                    for match in matches {
                        if SubStr(match, 1, StrLen(prefix)) = prefix
                            changed := session.Refresh(match) || changed
                    }
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
