#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "extensions/ArrayExtensions"

/**
 * Stands in for a Profiler when `--profile` is off. Wrap hands callbacks back
 * untouched, so the walk pays nothing for the instrumentation.
 */
class NullProfiler {
    enabled := false
    owner := ""
    files := 0
    nodes := 0

    Phase(*) => ""
    Init(*) => ""
    Wrap(callback) => callback
}

/**
 * Timing for `--profile`. Collects two things:
 *
 * - Phases: disjoint stretches of the run (parse, walk, output, ...), summed over
 *   every file. Whatever falls between them is reported as unaccounted.
 * - Lints: the time each lint spends in its constructor and in its listeners.
 *   Listeners are wrapped as they are registered, against `owner`, the id of the
 *   lint whose constructor is running.
 *
 * A wrapped listener reports self time: a listener that runs others (the scope
 * tracker runs the OnComplete callbacks) does not also count their time.
 */
export class Profiler {
    /** @type {NullProfiler} */
    static NULL := NullProfiler()

    static _freq := 0

    static __New() {
        if this != Profiler
            return
        DllCall("QueryPerformanceFrequency", "uint64*", &freq := 0) ;@ahklint-ignore use-type-classes
        Profiler._freq := freq
    }

    /**
     * The performance counter, in ticks
     * @returns {Integer}
     */
    static Now() => (DllCall("QueryPerformanceCounter", "uint64*", &t := 0), t) ;@ahklint-ignore use-type-classes

    enabled := true

    /** The id that listeners registered now are attributed to */
    owner := ""

    /** Files linted */
    files := 0

    /** Nodes walked, counting each pass of a --fix relint */
    nodes := 0

    _phases := Map()
    _order := []
    _lints := Map()
    _child := 0

    __New() {
        this._start := Profiler.Now()

        ; Everything before this point - loading the exe and the DLLs, running
        ; static initializers - is timed from the process's creation
        DllCall("GetSystemTimePreciseAsFileTime", Int64.Ptr, &now := 0)
        created := Profiler._ProcessTimes().created
        this.Phase("startup", this._start - (now - created) * Profiler._freq // 10000000)
    }

    /**
     * Add the time since `since` to a phase.
     *
     * @param {String} name the phase
     * @param {Integer} since a reading of `Profiler.Now()`
     * @param {Integer} count how many calls this is; 0 adds to the last call
     */
    Phase(name, since, count := 1) {
        elapsed := Profiler.Now() - since
        if !this._phases.Has(name) {
            this._phases[name] := { ticks: 0, calls: 0 }
            this._order.Push(name)
        }
        bucket := this._phases[name]
        bucket.ticks += elapsed
        bucket.calls += count
    }

    /**
     * Add the time since `since` to a lint's constructor time.
     *
     * @param {String} id the lint
     * @param {Integer} since a reading of `Profiler.Now()`
     */
    Init(id, since) {
        bucket := this._Lint(id)
        bucket.init += Profiler.Now() - since
        bucket.inits++
    }

    /**
     * Wrap a listener so its time is added to `owner`.
     *
     * @param {Func(Any, Any) => Any} callback the listener
     * @returns {Func(Any, Any) => Any} the timed listener
     */
    Wrap(callback) {
        bucket := this._Lint(this.owner)
        self := this

        Timed(a, b) {
            outer := self._child, self._child := 0
            DllCall("QueryPerformanceCounter", "uint64*", &t0 := 0) ;@ahklint-ignore use-type-classes
            callback(a, b)
            DllCall("QueryPerformanceCounter", "uint64*", &t1 := 0) ;@ahklint-ignore use-type-classes
            elapsed := t1 - t0
            bucket.ticks += elapsed - self._child
            bucket.calls++
            self._child := outer + elapsed
        }
        return Timed
    }

    _Lint(id) {
        if !this._lints.Has(id)
            this._lints[id] := { id: id, init: 0, inits: 0, ticks: 0, calls: 0 }
        return this._lints[id]
    }

    /**
     * Write the report.
     * @param {File} out where to write it
     */
    Report(out) {
        wall := this._phases["startup"].ticks + Profiler.Now() - this._start
        cpu := Profiler._ProcessTimes()
        overhead := this._MeasureWrapper()

        ms := (ticks) => ticks * 1000 / Profiler._freq
        pct := (ticks) => wall ? ticks * 100 / wall : 0

        lints := []
        callbackTicks := 0, callbackCalls := 0
        for _, bucket in this._lints {
            lints.Push(bucket)
            callbackTicks += bucket.ticks
            callbackCalls += bucket.calls
        }
        lints.Sort((a, b) => (b.init + b.ticks) - (a.init + a.ticks))

        out.WriteLine(Format("ahklint --profile: {} files, {} nodes walked, {:.1f} ms wall "
            "({:.1f} ms user, {:.1f} ms kernel CPU)",
            this.files, this.nodes, ms(wall), cpu.user / 10000, cpu.kernel / 10000))
        out.WriteLine("")

        out.WriteLine(Format("{:-24}{:12}{:8}{:9}", "phase", "ms", "%", "calls"))
        accounted := 0
        for name in this._order {
            bucket := this._phases[name]
            accounted += bucket.ticks
            out.WriteLine(Format("{:-24}{:12.2f}{:8.1f}{:9}", name, ms(bucket.ticks), pct(bucket.ticks), bucket.calls))
            if name == "walk" {
                visitor := bucket.ticks - callbackTicks
                out.WriteLine(Format("{:-24}{:12.2f}{:8.1f}", "  visitor (no lints)", ms(visitor), pct(visitor)))
                out.WriteLine(Format("{:-24}{:12.2f}{:8.1f}{:9}", "  lint listeners", ms(callbackTicks), pct(callbackTicks), callbackCalls))
            }
        }
        rest := wall - accounted
        out.WriteLine(Format("{:-24}{:12.2f}{:8.1f}", "unaccounted", ms(rest), pct(rest)))
        out.WriteLine("")

        out.WriteLine(Format("{:-32}{:10}{:10}{:10}{:10}{:8}", "lint", "init ms", "walk ms", "calls", "us/call", "%"))
        for bucket in lints {
            out.WriteLine(Format("{:-32}{:10.2f}{:10.2f}{:10}{:10.2f}{:8.1f}",
                bucket.id, ms(bucket.init), ms(bucket.ticks), bucket.calls,
                bucket.calls ? ms(bucket.ticks) * 1000 / bucket.calls : 0,
                pct(bucket.init + bucket.ticks)))
        }
        out.WriteLine("")

        out.WriteLine(Format("Listener times include the instrumentation; a wrapped no-op takes {:.2f} us "
            "more than a bare one, {:.2f} us of it inside the timed region.",
            overhead.total, overhead.inside))
        out.WriteLine(Format("Over {} calls that is ~{:.1f} ms, split between the lint rows and the visitor row.",
            callbackCalls, callbackCalls * overhead.total / 1000))
        out.WriteLine("Process teardown after this report is not included; compare against an external timer.")
    }

    /**
     * Time a wrapped no-op listener against a bare one.
     * @returns {Object} `total` and `inside` (the part a lint row sees), in microseconds per call
     */
    _MeasureWrapper() {
        static N := 20000
        Noop(*) {
            ; does nothing
        }

        probe := Profiler()
        probe.owner := "probe"
        wrapped := probe.Wrap(Noop)

        t := Profiler.Now()
        loop N
            Noop(1, 2)
        bare := Profiler.Now() - t

        t := Profiler.Now()
        loop N
            wrapped(1, 2)
        timed := Profiler.Now() - t

        usPerTick := 1000000 / Profiler._freq
        return {
            total: (timed - bare) * usPerTick / N,
            inside: probe._lints["probe"].ticks * usPerTick / N
        }
    }

    /**
     * This process's creation time and CPU time so far, in 100ns FILETIME units
     * @returns {Object} `created`, `kernel`, `user`
     */
    static _ProcessTimes() {
        DllCall("GetProcessTimes", IntPtr, DllCall("GetCurrentProcess", IntPtr),
            Int64.Ptr, &created := 0, Int64.Ptr, &exited := 0, Int64.Ptr, &kernel := 0, Int64.Ptr, &user := 0)
        return { created: created, kernel: kernel, user: user }
    }
}
