#Requires AutoHotkey v2.1-alpha.30 64-bit

; JSON.ahk is a plain v2.0 class (no `export`); it can still be imported by
; naming it explicitly - `export` only affects wildcard imports.
#Import "lib/JSON.ahk" { JSON }

/**
 * Resolved linter configuration: the single source of truth for which lints run
 * and at what severity. Built from a parsed config object (a JSON map, possibly
 * empty), the lint registry, and an already-resolved target version.
 *
 * The schema:
 *
 *     {
 *         "target":  "2.1-alpha.30",       // resolved by the caller, not here
 *         "extends": "recommended",        // "recommended" | "all" | "none"
 *         "lints": {
 *             "no-goto":    "error",        // "off" | "warn" | "error"
 *             "one-requires": ["warn", {}]  // tuple: severity + (future) options
 *         }
 *     }
 *
 * Resolution: start from the `extends` preset (default "recommended", enabling
 * every lint with meta.recommended at its meta.severity), then apply the `lints`
 * overrides on top. Every referenced lint id and the `extends` value are
 * validated against the registry, so typos fail fast (DESIGN.md §7).
 */
export class Config {
    /**
     * @param {Map}    parsed   the parsed config object, or an empty Map for defaults
     * @param {Array}  registry ALL_LINTS - lint classes, each with a static `meta`
     * @param {String} target   the resolved target AHK version
     */
    __New(parsed, registry, target) {
        this.target    := target
        this._severity := Map()   ; lint id -> "off" | "warn" | "error"
        this._options  := Map()   ; lint id -> options object (reserved for meta.schema)
        this._Resolve(parsed, registry)
    }

    /** A default config (no file): the recommended preset at the given target. */
    static Default(registry, target) => Config(Map(), registry, target)

    /**
     * Read and parse a JSONC config file into a plain object (a Map). Strips
     * comments before parsing since cJson is strict JSON. Throws on a missing
     * file, malformed JSON, or a non-object root.
     */
    static ParseFile(path) {
        parsed := JSON.Parse(FileRead(path, "UTF-8"))
        if !(parsed is Map)
            throw ValueError('Config root must be a JSON object: ' path, -1)
        return parsed
    }

    /**
     * Walk up from `startDir` looking for the first `.ahklint.json` (or
     * `ahklint.json`). Returns the path, or "" if none is found.
     */
    static Discover(startDir) {
        static NAMES := [".ahklint.json", "ahklint.json"]
        dir := startDir
        loop {
            for name in NAMES {
                candidate := dir "\" name
                if FileExist(candidate)
                    return candidate
            }
            SplitPath(dir, , &parent)
            if (parent == "" || parent == dir)
                break
            dir := parent
        }
        return ""
    }

    /** Effective severity for a lint id: "off" | "warn" | "error". */
    SeverityFor(id) => this._severity.Has(id) ? this._severity[id] : "off"

    /** Is this lint enabled (effective severity is not "off")? */
    IsEnabled(id) => this.SeverityFor(id) != "off"

    _Resolve(parsed, registry) {
        metaById := Map()
        for cls in registry {
            m := cls.meta
            metaById[m.id] := m
        }

        extends := parsed.Has("extends") ? parsed["extends"] : "recommended"
        switch extends {
            case "recommended":
                for id, m in metaById
                    if m.recommended
                        this._severity[id] := this._NormSeverity(m.severity, id)
            case "all":
                for id, m in metaById
                    this._severity[id] := this._NormSeverity(m.severity, id)
            case "none":
                ; start from nothing; the lints map turns rules on explicitly
            default:
                throw ValueError('Unknown preset in "extends": "' extends '" '
                    . '(expected "recommended", "all", or "none")', -1)
        }

        if !parsed.Has("lints")
            return

        lints := parsed["lints"]
        if !(lints is Map)
            throw ValueError('Config "lints" must be a JSON object', -1)

        for id, val in lints {
            if !metaById.Has(id)
                throw ValueError('Unknown lint id in config: "' id '"', -1)
            this._severity[id] := this._SeverityFromValue(val, id)
        }
    }

    /** A config value is either a severity string or a `[severity, options]` tuple. */
    _SeverityFromValue(val, id) {
        if (val is Array) {
            if !val.Length
                throw ValueError('Empty config tuple for lint "' id '"', -1)
            if (val.Length >= 2)
                this._options[id] := val[2]   ; TODO parse options
            return this._NormSeverity(val[1], id)
        }
        return this._NormSeverity(val, id)
    }

    _NormSeverity(sev, id) {
        if !(sev is String)
            throw ValueError('Severity for lint "' id '" must be a string', -1)
        switch sev {
            case "off", "warn", "error":
                return sev
            default:
                throw ValueError('Invalid severity "' sev '" for lint "' id '" '
                    . '(expected "off", "warn", or "error")', -1)
        }
    }
}
