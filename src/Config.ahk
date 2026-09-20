#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "cJson\JSON.ahk" { JSON }

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
 *             "quote-style": ["warn", { "style": "single" }]  // tuple: severity + options
 *         }
 *     }
 *
 * Resolution: start from the `extends` preset (default "recommended", enabling
 * every lint with meta.recommended at its meta.severity), then apply the `lints`
 * overrides on top. Every referenced lint id and the `extends` value are
 * validated against the registry, so typos fail fast (DESIGN.md §7).
 *
 * Options: a lint that takes options declares them in `meta.options`, keyed by
 * option name:
 *
 *     options: {
 *         style: { type: "string", default: "double", values: ["double", "single"],
 *                  description: "..." }
 *     }
 *
 * `type` is "string" | "number" | "boolean"; `values` optionally restricts the
 * option to an enum. Every lint gets its defaults, and user-supplied options are
 * validated against the declaration and merged on top, so `OptionsFor` always
 * returns a complete object.
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
        this._options  := Map()   ; lint id -> resolved options object (defaults + overrides)
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

    /**
     * Resolved options for a lint id: every option declared in its meta.options,
     * at its configured value or its default. A copy, since one Config is shared
     * by every file in a run. Lints without options get an empty object.
     */
    OptionsFor(id) => this._options.Has(id) ? this._options[id].Clone() : {}

    /**
     * The metas of every lint this config enables, in registry order.
     *
     * Output formats need to describe the rules that ran, not just the findings:
     * a SARIF driver lists them under `tool.driver.rules`, and a language server
     * announces them. Answering from the config means neither has to construct a
     * Linter or walk a tree.
     *
     * @returns {Array<Object>}
     */
    EnabledMetas() {
        enabled := []
        for meta in this._metas
            if this.IsEnabled(meta.id)
                enabled.Push(meta)
        return enabled
    }

    _Resolve(parsed, registry) {
        this._metas := []         ; registry order, for EnabledMetas
        metaById := Map()
        for cls in registry {
            m := cls.meta
            metaById[m.id] := m
            this._metas.Push(m)
            this._options[m.id] := Config._DefaultOptions(m)
        }

        extends := parsed.Has("extends") ? parsed["extends"] : "recommended"
        switch StrLower(extends) {
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
            this._severity[id] := this._SeverityFromValue(val, metaById[id])
        }
    }

    /** A config value is either a severity string or a `[severity, options]` tuple. */
    _SeverityFromValue(val, meta) {
        id := meta.id
        if (val is Array) {
            if !val.Length
                throw ValueError('Empty config tuple for lint "' id '"', -1)
            if (val.Length > 2)
                throw ValueError('Config tuple for lint "' id '" must be [severity, options]', -1)
            if (val.Length == 2)
                this._ApplyOptions(val[2], meta)
            return this._NormSeverity(val[1], id)
        }
        return this._NormSeverity(val, id)
    }

    /** Build a lint's default options object from its meta.options declaration. */
    static _DefaultOptions(meta) {
        opts := {}
        if !HasProp(meta, "options")
            return opts
        for name, spec in meta.options.OwnProps() {
            if !HasProp(spec, "default") || !HasProp(spec, "type")
                throw ValueError(Format('Option "{1}" of lint "{2}" must declare a type and default',
                    name, meta.id), -1)
            ;@ahkbuild-safe
            opts.%name% := spec.default
        }
        return opts
    }

    /** Validate user-supplied options against meta.options and merge them over the defaults. */
    _ApplyOptions(userOpts, meta) {
        id := meta.id
        if !(userOpts is Map)
            throw ValueError('Options for lint "' id '" must be a JSON object', -1)

        declared := HasProp(meta, "options") ? meta.options : {}
        resolved := this._options[id]
        for name, val in userOpts {
            if !HasProp(declared, name)
                throw ValueError(Format('Unknown option "{1}" for lint "{2}"', name, id), -1)
            ;@ahkbuild-safe
            resolved.%name% := Config._NormOption(val, declared.%name%, name, id)
        }
    }

    /**
     * Check one option value against its declaration. Enum values match
     * case-insensitively (like severities) and normalize to the declared spelling.
     */
    static _NormOption(val, spec, name, id) {
        switch spec.type {
            case "string":  ok := val is String
            case "number":  ok := val is Number
            case "boolean": ok := val is Integer && (val == 0 || val == 1)   ; cJson decodes bools as 1/0
            default:
                throw ValueError(Format('Option "{1}" of lint "{2}" has unknown type "{3}"',
                    name, id, spec.type), -1)
        }
        if !ok
            throw ValueError(Format('Option "{1}" for lint "{2}" must be a {3}', name, id, spec.type), -1)

        if !HasProp(spec, "values")
            return val

        expected := ""
        for allowed in spec.values {
            if (allowed = val)
                return allowed
            expected .= (expected == "" ? "" : ", ") '"' allowed '"'
        }
        throw ValueError(Format('Invalid value "{1}" for option "{2}" of lint "{3}" (expected {4})',
            val, name, id, expected), -1)
    }

    _NormSeverity(sev, id) {
        if !(sev is String)
            throw ValueError('Severity for lint "' id '" must be a string', -1)
        switch StrLower(sev) {
            case "off", "warn", "error":
                return StrLower(sev)
            default:
                throw ValueError('Invalid severity "' sev '" for lint "' id '" '
                    . '(expected "off", "warn", or "error")', -1)
        }
    }
}
