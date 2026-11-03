#Requires AutoHotkey v2.1-alpha.30

/**
 * A lint was ignored that didn't fire
 */
class UnusedLintIgnore {
    static meta => {
        id:          "unused-lint-ignore",
        title:       "Unused Lint Ignore",
        category:    "suspicious",
        versions:    ">=2.0",
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
     * @returns {unset?}
     */
    Check(linter, _) {
        for _, directives in linter.ignores {
            for directive in directives {
                if directive.used
                    continue

                msg := Format("Lint ``{1}`` is ingored but didn't fire", directive.id)
                linter.Report(UnusedLintIgnore.meta, directive.node, msg)
            }
        }
    }
}
