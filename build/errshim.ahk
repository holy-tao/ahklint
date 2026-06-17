PrintError(err) {
    msg := Type(err) ": " err.Message "`n"
    if err.Extra != "" {
        msg .= "    Specifically: " err.Extra "`n"
    }
    msg .= "`n" err.Stack

    FileAppend(msg, "**")
}

; Print caught errors to stderr
OnError((err, mode) {
    try {
        PrintError(err)
    } catch Error as another {
        another.Message .= "`r`n    > While processing a(n) " Type(err)
        PrintError(another)
    }
    ExitApp(2)
})