#Requires AutoHotkey v2.1-alpha.30

#Import "../../lib/Util.ahk" { FlattenNode, GetArg, StrJoin }

/**
 * Map of blocking Win32 functions to how they block. Each entry has:
 *  - `alts`: suggested AHK alternatives (possibly empty)
 *  - `timeout` (optional): 0-based index of the Win32 parameter that, when a literal
 *    zero, makes the call return immediately instead of waiting
 *  - `overlapped` (optional): 0-based index of an `LPOVERLAPPED` parameter; the call
 *    is only synchronous when it is a literal zero (NULL)
 *
 * Indices are Win32 parameter positions, not DllCall argument positions. Names are
 * stored without an A/W suffix; lookups fall back to stripping one.
 * @type {Map<String, Object>}
 */
BLOCKING_CALLS := Map()
BLOCKING_CALLS.CaseSense := "off"
BLOCKING_CALLS.Set(
    ; Sleeps
    "Sleep",                            { alts: ["Sleep"], timeout: 0 },
    "SleepEx",                          { alts: ["Sleep"], timeout: 0 },
    "NtDelayExecution",                 { alts: ["Sleep"] },
    "ZwDelayExecution",                 { alts: ["Sleep"] },

    ; Handle waits
    "WaitForSingleObject",              { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 1 },
    "WaitForSingleObjectEx",            { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 1 },
    "WaitForMultipleObjects",           { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 3 },
    "WaitForMultipleObjectsEx",         { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 3 },
    "SignalObjectAndWait",              { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 2 },
    "MsgWaitForMultipleObjects",        { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 3 },
    "MsgWaitForMultipleObjectsEx",      { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 2 },
    "CoWaitForMultipleHandles",         { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 1 },
    "CoWaitForMultipleObjects",         { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"], timeout: 1 },
    ; Nt* timeouts are PLARGE_INTEGER pointers, so a literal can't tell us the duration
    "NtWaitForSingleObject",            { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"] },
    "NtWaitForMultipleObjects",         { alts: ["ProcessWait", "ProcessWaitClose", "RunWait"] },

    ; Locks and synchronization primitives
    "EnterCriticalSection",             { alts: [] },
    "AcquireSRWLockExclusive",          { alts: [] },
    "AcquireSRWLockShared",             { alts: [] },
    "SleepConditionVariableCS",         { alts: [], timeout: 2 },
    "SleepConditionVariableSRW",        { alts: [], timeout: 2 },
    "WaitOnAddress",                    { alts: [], timeout: 3 },
    "EnterSynchronizationBarrier",      { alts: [] },
    "WaitForThreadpoolWorkCallbacks",   { alts: [] },
    "WaitForThreadpoolTimerCallbacks",  { alts: [] },
    "WaitForThreadpoolWaitCallbacks",   { alts: [] },
    "WaitForThreadpoolIoCallbacks",     { alts: [] },
    "SuspendThread",                    { alts: ["Pause", "Suspend"] },

    ; Process, debugger, and message waits
    "WaitForInputIdle",                 { alts: ["WinWait", "WinWaitActive"], timeout: 1 },
    "WaitForDebugEvent",                { alts: [], timeout: 1 },
    "WaitForDebugEventEx",              { alts: [], timeout: 1 },
    "GetMessage",                       { alts: ["OnMessage"] },
    "WaitMessage",                      { alts: ["OnMessage", "Sleep"] },
    "SendMessage",                      { alts: ["SendMessage"] },

    ; IPC and completion waits. WaitNamedPipe and CallNamedPipe have no `timeout`:
    ; 0 there means NMPWAIT_USE_DEFAULT_WAIT, not "don't wait".
    "ConnectNamedPipe",                 { alts: [], overlapped: 1 },
    "TransactNamedPipe",                { alts: [], overlapped: 6 },
    "WaitNamedPipe",                    { alts: [] },
    "CallNamedPipe",                    { alts: [] },
    "GetQueuedCompletionStatus",        { alts: [], timeout: 4 },
    "GetQueuedCompletionStatusEx",      { alts: [], timeout: 4 },
    "GetOverlappedResult",              { alts: [], timeout: 3 },
    "GetOverlappedResultEx",            { alts: [], timeout: 3 }
)

class OSThreadBlock {
    static meta => {
        id:          "os-thread-block",
        title:       "OS Thread Block",
        category:    "threading",
        versions:    ">=2.0",
        severity:    "error",
        fixable:     "none",
        recommended: true,
        references:  ["https://www.autohotkey.com/docs/v2/misc/Threads.htm"]
    }

    __New(linter) {
        linter.OnEnter(["function_call", "call_statement"], this.Evaluate.Bind(this))
    }

    /**
     * Evaluate a function call or call statement to see if the rule should apply
     * @param {Linter} linter the linter
     * @param {Node} node the tree-sitter node to evaluate
     */
    Evaluate(linter, node) {
        if node.GetChildByFieldName("function").Text != "DllCall" {
            return
        }

        argSeq := node.GetChildByFieldName("arguments")
        if argSeq.IsNull || (argSeq.NamedChildCount < 1) {
            return
        }

        arg1 := FlattenNode(argSeq.GetNamedChild(0))
        if arg1.Type != "string_literal"
            return

        ; Drop the quotes and any "module\" or "path/to/module.dll\" prefix
        fnName := Trim(RegExReplace(SubStr(arg1.Text, 2, -1), ".*[\\/]"))
        if !(entry := OSThreadBlock.Lookup(&fnName))
            return

        if entry.HasProp("timeout") && OSThreadBlock.IsLiteralZero(node, entry.timeout)
            return
        if entry.HasProp("overlapped") && !OSThreadBlock.IsLiteralZero(node, entry.overlapped)
            return

        message := "Do not block the OS thread"
        if entry.alts.Length > 0
            message .= ". Consider using: " StrJoin(", ", entry.alts*)
        if entry.HasProp("timeout") && !(fnName ~= "i)^Sleep(Ex)?$")
            message .= (entry.alts.Length > 0 ? ", or" : ". Consider") " polling with a zero timeout and Sleep"

        linter.Report(OSThreadBlock.meta, argSeq.GetNamedChild(0), message)
    }

    /**
     * Find the entry for a function name, falling back to stripping an A/W suffix.
     * @param {VarRef<String>} fnName the name; set to the matched key on success
     * @returns {Object | String} the entry, or "" if the function isn't a blocking call
     */
    static Lookup(&fnName) {
        if BLOCKING_CALLS.Has(fnName)
            return BLOCKING_CALLS.Get(fnName)

        base := SubStr(fnName, 1, -1)
        if (fnName ~= "i)[AW]$") && BLOCKING_CALLS.Has(base) {
            fnName := base
            return BLOCKING_CALLS.Get(base)
        }
        return ""
    }

    /**
     * Whether a Win32 parameter of a DllCall is a literal zero / false. A DllCall's
     * value for Win32 parameter `i` is its argument `2 + 2i` (after the function name
     * and the parameter's type string).
     * @param {Node} call the DllCall node
     * @param {Integer} paramIndex the 0-based Win32 parameter index
     */
    static IsLiteralZero(call, paramIndex) {
        arg := GetArg(call, 2 + 2 * paramIndex) ?? 0
        if !arg
            return false

        arg := FlattenNode(arg)
        switch arg.Type {
            case "integer_literal", "hex_literal":
                return Integer(arg.Text) == 0
            case "boolean_literal":
                return arg.Text = "false"
            default:
                return false
        }
    }
}
