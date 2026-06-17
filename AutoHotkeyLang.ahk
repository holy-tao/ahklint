#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "lib/tree-sitter" { Language }

/**
 * The tree-sitter-autohotkey grammar exposed as a Language. The backing DLL is
 * loaded by the entry point (ahklint.ahk) via #DllLoad.
 */
export struct AutoHotkeyLang extends Language {
    __New() {
        ptr := DllCall("tree-sitter-autohotkey\tree_sitter_autohotkey", "cdecl ptr")
        super.__New(ptr)
    }
}
