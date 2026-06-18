# Build Scripts

AhkLint relies on a set of standalone build scripts for generating the lint barrel file and static site. These are not bundled into the final executable, but exist to extract metadata and help with build processes. How many times can I write "build" in a README file? Build, build, build, build, build.

All scripts here should assume that they might be run in a ci/cd context and should never use blocking UI functions like MsgBox, should print errors to stdout, and should return with nonzero exit codes on failure.

## Scripts

- `barrel.ahk` — scans `lints/` and regenerates the `lints/all.ahk` barrel (the `ALL_LINTS` manifest the linter imports). Run this first; the others depend on a current barrel.
- `compile-docs.ahk` — merges each lint's static `meta` with its sibling `.md` prose into one Hugo page per lint under `site/content/lints/<category>/<id>.md`. Generated pages are gitignored; CI regenerates them before `hugo`. Fails if a lint has no `.md` or no `;~ <id>` example.
- `errshim.ahk` — `#Include`d (not imported) by the above to print caught errors to stderr and exit nonzero, so a failure is visible in CI.