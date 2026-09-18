#Requires AutoHotkey v2.1-alpha.30

#Import "extensions/ArrayExtensions"
#Import "extensions/MapExtensions"

class DuplicateHotkeyModifier {
    static meta => {
        id:          "duplicate-hotkey-modifier",
        title:       "Duplicate Hotkey Modifier",
        category:    "hotkeys",
        versions:    ">=2.0",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  [
            "https://www.autohotkey.com/docs/alpha/Hotkeys.htm#Symbols",
            "https://www.autohotkey.com/docs/alpha/Hotstrings.htm#Options"
        ]
    }

    __New(linter) {
        linter.OnEnter("hotkey", this.SeeHotkey.Bind(this))
        linter.OnEnter("hotstring", this.SeeHotstring.Bind(this))
    }

    SeeHotkey(linter, node) {
        trigger := node.GetChildByFieldName("trigger")
        if trigger.IsNull {
            throw Error("Hotkey trigger node was null!")
        }

        hasDuplicates := trigger.GetNamedChildren()
            .Filter(child => child.type !~= "key_identifier|hotkey_trigger|hotkey_and")
            .GroupBy(child => child.type)
            .Any((_key, group) => group.Length > 1)

        if hasDuplicates {
            linter.Report(DuplicateHotkeyModifier.meta, trigger, "Hotkey trigger contains duplicate modifiers.")
        }        
    }

    SeeHotstring(linter, node) {
        modifiers := node.GetChildByFieldName("modifiers")
        if modifiers.IsNull
            return ; Hotstrings might not have modifiers

        hasDuplicates := modifiers.GetNamedChildren()
            .GroupBy(child => child.type)
            .Any((_key, group) => group.Length > 1)

        if hasDuplicates {
            linter.Report(DuplicateHotkeyModifier.meta, modifiers, "Hotstring contains duplicate options.")
        }
    }
}