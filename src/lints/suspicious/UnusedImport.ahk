#Requires AutoHotkey v2.1-alpha.30

/**
 * Checks for unused imports.
 */
class UnusedImport {
    static meta => {
        id:          "unused-import",
        title:       "Unused Import",
        category:    "suspicious",
        versions:    ">=2.1-alpha.20",
        severity:    "warn",
        fixable:     "none",
        recommended: true,
        references:  []
    }

    __New(linter) {
        linter.scopes.OnComplete(this.Check.Bind(this))
    }

    /**
     * @param {Linter} linter the linter
     * @param {ScopeTracker} scopes the linter's scope tracker
     * @returns {unset?}
     */
    Check(linter, scopes) {
        for scope in scopes.all {
            for name, variable in scope.variables {
                ; only check imports here, allow reads or writes
                if variable.kind != "import" || variable.reads.length > 0 || variable.writes.length > 0
                    continue

                linter.Report(
                    UnusedImport.meta,
                    variable.declaration,
                    Format("Name ``{1}`` is imported but never used", name)
                )
            }
        }
    }
}
