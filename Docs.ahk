#Requires AutoHotkey v2.1-alpha.30 64-bit

/**
 * Single source of truth for the published documentation URL.
 *
 * A lint's doc URL is mechanically `DOCS_BASE <id>` - there is nothing per-lint
 * to author, so it is *derived* rather than stored in each `meta` (which used to
 * carry a hand-written `docs:` field that could silently drift from the id).
 *
 * This MUST stay in sync with the docs site's routing:
 *   - Hugo `baseURL`            = "https://holy-tao.github.io/ahklint/"
 *   - each generated page's url = "/lints/<id>/"
 * so `DOCS_BASE <id>` resolves to a real page. See DESIGN.md "9. Documentation".
 */
export global DOCS_BASE := "https://holy-tao.github.io/ahklint/lints/"

/**
 * The published documentation URL for a lint.
 * @param {String} id the lint's `meta.id`
 * @returns {String}
 */
export DocsUrl(id) {
    return DOCS_BASE id
}
