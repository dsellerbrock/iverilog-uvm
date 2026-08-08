# IEEE 1800-2017 Clause Conformance Matrix

Governing milestone: **M14B — exhaustive subclause campaign.** The table below
is the retained M14 simulation-led snapshot. It is useful evidence, but it is
**not** a full-compliance certificate and its `FULL` labels are provisional
until M14B replaces them with the multidimensional matrix described below.

Every disposition here is **empirical** — established by compiling and running
representative constructs against the installed simulator, not from
documentation or memory (manifesto principle 1/3). The original audit checked
computed values on representative constructs. It did not exhaust every
subclause or separately prove synthesis, SVA, UVM/DPI, diagnostic and bounded-
termination behavior. OpenTitan has since demonstrated why those dimensions
cannot be inferred from a small simulation probe.

## M14B replacement gate

Each subclause/grammar-production row will have separate evidence cells for:

| Dimension | Required evidence |
|---|---|
| Parse | legal forms accepted; illegal forms rejected at the right boundary |
| Elaborate | names, hierarchy, parameters and overload/specialization choices resolve correctly |
| Contextual type | width, sign, 2/4-state, enum and aggregate identity preserved in every legal context |
| Simulation | computed values and object/container effects match an explicit oracle |
| Scheduling | region, lifetime, race boundary and end-of-simulation traces match the standard |
| Synthesis | legal synthesizable forms lower without process fallback, crash or semantic debt |
| SVA | grammar, attempts, sampling, scheduling, actions and assertion VPI are verified |
| UVM/class runtime | class, constraint, coverage and reusable-library behavior executes, not merely compiles |
| DPI/VPI | ABI, directions, lifetime, concurrency, re-entry and data round trips are verified |
| Diagnostics | unsupported/illegal forms fail loudly and locally; no compile-progress stub or dropped construct |
| Termination | permanent probes and frozen corpora finish within a declared resource bound |
| Differential | pinned Slang and sv-tests results are recorded; disagreements are resolved against IEEE 1800-2017 |

`FULL` in the replacement matrix means every applicable cell has permanent
positive, negative, semantic and interaction evidence. `UNKNOWN` is not a pass,
and parser acceptance cannot stand in for lowering or runtime behavior. Slang
is used for parsing/elaboration/static-semantics comparison; it is not treated
as a simulator or as the definition of the standard.

## Legend

| Code | Meaning |
|------|---------|
| **FULL** | Legacy M14 label: legal syntax, resolution, typing and runtime behaviour were correct on the probed simulation constructs; provisional until M14B. |
| **PARTIAL** | Core behaviour correct; specific sub-features are recorded corners (listed). |
| **DIAGNOSED** | Not implemented, but rejected with an explicit, loud diagnostic (error/sorry/one-time warning). No silent miscompile. |
| **N/A** | Clause is informative/organizational or not applicable to a simulation tool. |

Manifesto principle 4 forbids **silent** miscompiles: every unsupported
construct must be a loud diagnostic, a correct implementation, or a
deliberately-specified safe lowering. The M14 audit found six remaining
silent gaps; all six are closed (four fixed, two converted to loud
diagnostics) — see **§ M14 gap closures** below.

## Matrix

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 1 | Overview | N/A | Informative. |
| 2 | Normative references | N/A | Informative. |
| 3 | Design & verification building blocks | FULL | modules, programs, interfaces, packages, checkers(diag), primitives, compilation unit ($unit) all parse and elaborate; see clauses 23–29. |
| 4 | Scheduling semantics | FULL | Full stratified queue: Preponed, Active, Inactive, NBA, the post-NBA `cbNBASynch` point, Observed, the Reactive set (Reactive / Re-Inactive / Re-NBA), Pre-Postponed and Postponed, drained in 4.4.2 order with per-event region tags. Concurrent assertions sample Preponed, evaluate in Observed and run their actions in Reactive; program processes and their `#0`/NBA use the reactive set; `$finish` drains the remaining regions of its own slot. Region trace and a reverse-insertion region self-test are built in (`IVL_REGION_TRACE`, `IVL_REGION_SELFTEST`), and a Postponed-region write is diagnosed. Evidence: m6_sched_litmus_test, m6_reactive_region_test, m6b_nba_sync (VPI), sv_assert_observed_region, sv_assert_reactive_action, sv_assert_reactive_drain. (Verified 2026-07-25.) |
| 5 | Lexical conventions | FULL | sized/based/underscored literals, real/time literals, unbased-unsized `'0/'1/'x/'z`, string escapes, `` `__FILE__ ``/`` `__LINE__ ``. |
| 6 | Data types | PARTIAL | logic/bit/reg/byte/shortint/int/longint/integer/time, real/shortreal/realtime, chandle, string(+methods), event, enum(+methods), typedef, void, signed/unsigned casts, nettypes all FULL. **Fixed in M4B-17:** an explicit full-width select of an enum now has packed-vector l-value typing while an unselected enum still enforces 6.19.3 compatibility. Corner: `$typename` returns the canonical base representation (e.g. `int`→`logic`), dropping ranges — a diagnosed-by-behaviour introspection limitation, not a value miscompile. |
| 7 | Aggregate data types | PARTIAL | Core packed/unpacked struct and union, tagged-union, multidimensional packed/unpacked array, dynamic-array, queue, associative-array, assignment-pattern, locator/reduction/ordering, streaming, `$cast`, and bitstream-cast forms are supported. **Fixed in M14:** module-static integer-keyed assoc value read (was a silent value-loss). **Fixed in M4B-16:** parentheses-free associative-array `size`/`num` now report the live entry count and agree with `size()`/`num()`. **Fixed subset in M4B-21:** an in-range constant partial prefix of a fixed multidimensional unpacked array is a subarray in the supported procedural-copy and continuous-assignment contexts, with declared-direction mapping, strict type/shape equivalence, original-net sensitivity, and per-word driver accounting. Run-time prefixes, out-of-range source-subarray values, procedural values with more than one residual dimension, class/property partial-prefix sources, and fixed-prefix sources assigned to class/aggregate-member destinations remain loud. Other corners: string/real-VALUED integer-keyed assoc (`string s[int]`) — narrow; `int a[*]` wildcard-key decl is a syntax error; `%p` on integral aggregates renders empty (has a stderr warning); member access on an element of an unpacked array of packed struct, and whole-array pattern assignment into such a class property, are fixed (were a crash and a silent zero-fill); class-property unpacked arrays of `real`/`string` still store every element to one slot (issue #100). |
| 8 | Classes | PARTIAL | new/ctor/this/super, single inheritance, virtual & pure-virtual dispatch, abstract classes, static members, const props, parameterized `#(T)`, typedef fwd-ref, protected/local, `$cast`, chained `C#(T)::m()` all FULL. **Fixed in M14:** width-1 (`bit`/`logic`) class-property `$display` (was garbage; value was always correct). Corners: interface classes / `implements`, nested class declarations, out-of-body `extern` method bodies (all syntax errors); shallow-copy inline static initializer `C b = new a;` at module scope (works as `C b; b = new a;`, and in automatic/class scope). |
| 9 | Processes | FULL | initial/always/always_comb/ff/latch, final, fork/join(/any/none), disable, disable fork, wait fork, static/automatic, `process::self`/`kill`/`await`, and `suspend`/`resume` with real `status()` states (M6B-1). A named begin/end shares the enclosing process identity; fork branches do not (9.3.1). **Fixed in M1B-6:** lazily elaborating a separately declared task/function from a caller's fork no longer makes its ordinary `return` lexically part of that fork; a `return` actually written in a fork remains an exact-gold compile error. (Verified 2026-08-08.) |
| 10 | Assignment statements | PARTIAL | Blocking/nonblocking, continuous assignment, assignment patterns, compound (`+=` etc.), `++`/`--`, and the listed aggregate-assignment subsets are supported. Full-width enum bit/part-select targets are preserved across both procedural and continuous assignment (M4B-17). Disjoint continuous/procedural terms on a multidimensional packed variable are checked in canonical flattened bit coordinates, while a true overlapping element remains an error (M4B-18). A run-time packed index after an unpacked-array word keeps both the word address and canonical packed offset (M4B-19). Fixed constant-prefix unpacked subarrays support blocking/NBA value copy and continuous l-values with left-to-left direction mapping, synthesis-safe lowering, and order-independent per-word overlap checks (M4B-21). Blocking unpacked-array function results also map declared left to declared left; the nonblocking form remains loud pending a per-word NBA snapshot. Residual M4B-20: driver conflict checking still treats packed terms inside one unpacked word as whole-word terms. Run-time unpacked-subarray prefixes and broader procedural residual shapes remain loud. Corner: net `alias` (syntax error). |
| 11 | Operators & expressions | PARTIAL | all arithmetic incl `**`, bitwise/logical/comparison/shift, `inside` (values AND ranges), `==?`/`!=?`, `?:` (incl 4-state), concat/replication, streaming, casts, string ops. Full-width enum selects retain their unsigned packed-vector expression type instead of the enum's named type (M4B-17); exact computed enum elements after an unpacked word retain their declared type (M4B-19). A constant fixed-unpacked prefix is consumable as a subarray value only in M4B-21's supported assignment contexts; there is not yet a general aggregate expression node for run-time/property/deeper-residual forms. Other residual: the general multidimensional packed computed-base path lacks per-dimension run-time out-of-bounds guards (an inner OOB index can alias a neighbouring outer slice) and does not yet reject every non-integral leading index. |
| 12 | Procedural programming statements | PARTIAL | if/else, `case`/`casex`/`casez`, `unique`/`unique0`/`priority` **case**, for/foreach/while/do-while/repeat/forever, break/continue/return all FULL. **Fixed in M14:** `case (x) inside` range matching (was low-endpoint-only silent miscompile). Corners: `unique`/`priority` **if**, `if (x matches p)`, `case matches` tag binding (all syntax errors / diagnosed). |
| 13 | Tasks and functions | PARTIAL | Tasks/functions, automatic/static lifetime, ref/const-ref/input/output/inout, default and named arguments, void functions, `void'()`, class/struct/array returns, and recursion are supported across the listed tested forms. **Fixed in M1B-6:** every task/function definition-body elaboration starts in its own lexical fork context, including lazy parameterized-class specialization reached from a forked caller; `sv_fork_lazy_param_typedef_return` pins both function and task bodies while `task_return_fail2` preserves the illegal lexical-fork boundary. A blocking unpacked-array function result can target a whole fixed array or fixed-prefix slice and preserves declared-order correspondence across opposite range directions. Residuals: the equivalent nonblocking assignment is rejected loudly until aggregate NBA snapshotting exists; a function returning an unpacked-array typedef assigned via `'{...}` aborts (ICE — loud but ungraceful). |
| 14 | Clocking blocks | FULL | **M8 CLOSED.** default/explicit clocking, input skew (#1step Preponed), output drives, `##N`, global clocking + `$global_clock`, clocking through virtual interfaces. |
| 15 | Interprocess synchronization & communication | PARTIAL | named events (`->`/`@`/`wait`/`.triggered`), semaphores, mailboxes (incl `#(T)`) all FULL. Corners: merged events (`e1 = e2`) diagnosed; `wait_order` (syntax error). |
| 16 | Assertions (SVA) | PARTIAL | Synthesized checkers, automaton (NFA) engine by default with the legacy linear engine behind `IVL_SVA_LEGACY=1` and a dual-run parity gate over both. `|->`/`|=>`, `##N`/`##[m:n]`/`##[m:$]` incl. mid-chain, `[*N]`/`[*m:n]`, goto/non-consecutive repetition, `and`/`or`/`intersect`/`within`/`throughout`, `not`/`first_match`, sequence local variables, `strong`/`weak`, `.triggered`/`.matched`, `expect`, procedural concurrent assertions with implicit clock inference, `disable iff`, sampled-value functions with real histories, named properties, defaults, pass/fail actions, cover, and the clause-40 VPI lifecycle. **Concurrent-assertion region placement is conformant (M6B-4):** every supported concurrent-assertion operand shape samples Preponed, evaluation runs in Observed, actions in Reactive. **Parameter-valued bounds are PARTIAL (M9-15):** the focused instance-sized implication/cover paths preserve exact/range/unbounded repetition and bounded-consequence expressions through instance override, reject invalid values during elaboration, and keep unsupported standalone symbolic ranges loud. **Variable-antecedent endpoint obligations remain OPEN (M9-16):** general NFA implication paths merge alternative endpoints instead of spawning one consequent obligation per match. **Deferred immediate assertions remain PARTIAL (R29), with a bounded `#0` Stage 1:** supported null/default-`$error()`/literal-`$display` reports are independent FIFO entries on the executing logical process, mature in Observed, execute in Reactive, and observe event/`wait` plus `always_comb`/`always_latch` reactivation flush points; module/generate items are live implicit `always_comb` processes and synthesis-transparent, labels preserve named hierarchy/`%m`, and `$assertoff` blocks new checks without cancelling queued reports. Illegal non-call/void-cast actions and report-producing source-final procedures are loud. General argument/receiver capture, task/function/class contexts, deferred cover, assertion-label/outermost-disable cancellation, `$assertkill`/VPI-reset queue cancellation, deferred-immediate VPI assertion identity/result callbacks, and per-time-step Postponed `final` remain unsupported. Loud sorries also remain for cross-clock overlapping implication and mid-sequence clock flow. |
| 17 | Checkers | PARTIAL | **M9-9.** `checker`/`endchecker` implemented on the module machinery: typed formals with directionless-defaults-to-input (17.4), default formal values, property/sequence declarations, `assert`/`assume`/`cover`, checker-local `default clocking`, internal variables and procedures, multiple independent instances, nested checker instantiation, `endchecker` labels, and `bind` of a checker. Loud residuals: untyped formals, event-typed formals, free (`rand`) variables (17.9), a checker DECLARED inside a module, procedural instantiation. sv_checker_basic, sv_checker_nested_instance, sv_checker_bind. (Verified 2026-07-25.) |
| 18 | Constrained random value generation | PARTIAL | rand/randc, `randomize()` with/without inline `with`, constraint blocks, `inside`, `dist`, implication, if-else constraints, `solve...before`, soft constraints **with 18.5.14.1 priority**, `disable soft`, `unique {}`, object- and per-field `rand_mode`/`constraint_mode`, pre/post_randomize, foreach and container-membership constraints, `randcase`, `randsequence`, and per-object/per-process RNG state (`srandom`/`get_randstate`/`set_randstate`) all FULL. Inherited constraints are solved as ONE set (M3B-8) and conflicting soft constraints are ranked by declaration order (M3B-9) — both were silent miscompiles. **Remaining gap:** the scope form `std::randomize(vars) with {...}` does not reach the solver — heuristic lowering as a statement, and loudly unenforced in expression context (M3B-10). **R3 CLOSED (Campaign 6, 2026-07-29):** every thread and class object is now seeded hierarchically at creation (18.13.1) — a fork child from its parent thread's generator, an object from its constructing thread's generator, a root/static thread from a fixed design-root generator in the same deterministic compile order as before — instead of falling back to a shared global generator; `srandom`/`get_randstate`/`set_randstate` (18.13.3-5) are unchanged. (Verified 2026-07-29.) |
| 19 | Functional coverage | FULL | **M11 CLOSED.** Full clause-19 bin semantics (multi-range fixed), transitions, crosses with `binsof`/`intersect`, ignore/illegal/default, `iff` guards, options, instance & type coverage, `$get_coverage`, durable report. |
| 20 | Utility system tasks & functions | FULL | `$clog2/$bits/$size/$dimensions/$left/$right/$low/$high/$increment`, `$isunknown/$onehot/$onehot0/$countones/$countbits`, `$info/$warning/$error/$fatal`, `$time/$realtime/$stime`, math funcs, `$random/$urandom/$urandom_range/$dist_*`. (`$typename` limitation recorded under clause 6.) |
| 21 | Input/output system tasks & functions | FULL | full `$display/$write/$monitor/$strobe` format set (`%b/%h/%d/%o/%s/%c/%e/%f/%g/%t/%p/%m/%v`), file I/O (`$fopen…$fscanf/$sscanf/$fgets/$fread`), `$readmem[hb]`/`$writememh`, `$sformat[f]/$swrite`, `$value$plusargs/$test$plusargs`, `$dumpfile/$dumpvars`. (`%p` on integral aggregates recorded under clause 7.) |
| 22 | Compiler directives | FULL | `` `define `` (args), `` `ifdef/`ifndef/`elsif/`else/`endif ``, `` `include/`undef ``, stringize `` `" ``, paste `` `` ``, line-continuation, `` `line/`__FILE__/`__LINE__ ``, `` `timescale/`default_nettype/`begin_keywords/`end_keywords/`pragma/`resetall/`celldefine/`unconnected_drive ``. |
| 23 | Modules and hierarchy | FULL | instantiation (position/name/`.*`/`.name`), param overrides (order/name), `defparam`, ANSI/non-ANSI ports, hierarchical refs, `bind` (**M13**), empty/unconnected ports. Corners: `extern module`, `$root` (diagnosed). |
| 24 | Programs | FULL | program block, ports, initial/final, multiple programs. Corners: anonymous program, `$exit` (diagnosed). |
| 25 | Interfaces | PARTIAL | interface + modport, parameters, arrays, `import`/`export` methods, clocking-in-interface, virtual interfaces as class properties (the UVM pattern), and modport direction enforcement. Continuous assignments depending on bare, constant-indexed, operator, multi/mixed, and type/size/sign-cast interface-member forms lower behaviorally and retrigger; virtual-interface any-change waits on packed signal members are initialized from and then observe the complete vector, and cast traversal fixes Caliptra's explicit interface-member-to-enum conversion (M5-2). Residual dependencies include runtime selector expressions inside identifiers, streaming, `inside`, function-call arguments/receivers, member-access bases and assignment-pattern values. VIF events on non-signal members are not supported; selected-bit and compound explicit events are operand/whole-member-change sensitive rather than exact selected/expression-result-change events. **Fixed in M14:** `$display` of a continuous-assign-driven interface member. Corner: `virtual <iface> v;` as a bare module-scope variable is a syntax error (class-property form works). |
| 26 | Packages | FULL | decl, `import pkg::*`/`import pkg::item`, typedef/param/function/class members, `::` resolution, `std::`, chained refs, ambiguous-import detection. Corners: a wildcard-imported typedef used as a type name; `export pkg::*` re-export (diagnosed). |
| 27 | Generate constructs | FULL | generate for (genvar), if/else, case, nested, named blocks + hierarchical access, module/assign/always instantiation, `generate`/`endgenerate`. |
| 28 | Gate- & switch-level modeling | FULL | all primitive gates, tristate (`bufif`/`notif`), MOS (`nmos/pmos/cmos` + resistive), `pullup`/`pulldown`, `tran`/`tranif`, drive strengths, gate delays, instance arrays. |
| 29 | User-defined primitives | FULL | combinational & sequential (level+edge) UDPs, UDP `initial`, instantiation, table syntax. |
| 30 | Specify blocks | FULL | **M13.** module path delays (`=>`/`*>`), edge-sensitive & state-dependent paths, `specparam`, `PATHPULSE$` — active with `-gspecify`. Corners: `pulsestyle`/`showcancelled` (diagnosed). |
| 31 | Timing checks | FULL | **M13.** `$setup/$hold/$recovery/$removal/$skew/$period/$width/$setuphold/$recrem` synthesize real violation checkers (`-gspecify`). Corners: `$nochange/$timeskew/$fullskew`, edge-descriptor event lists, tstamp/tcheck conditions (all loud sorries). |
| 32 | Backannotation (SDF) | PARTIAL | `$sdf_annotate` applies IOPATH delays with `-gspecify`; inert (loud warning) without it. Corner: only the first two arguments (file, scope) are used (diagnosed via warning). |
| 33 | Configuring the contents of a design | DIAGNOSED | `config`/`endconfig` (+ `design`/`liblist`/`instance`/`cell`) parse and are skipped with an explicit sorry; the design elaborates with default bindings. Library-map files are not parsed (syntax error). |
| 34 | Protected envelopes | PARTIAL | `` `pragma protect `` begin/end and `` `protect ``/`` `endprotect `` around **plaintext** compile and run (the envelope is transparent). Encrypted envelopes are not supported (no decryption). |
| 35 | Direct programming interface (DPI) | FULL | **M10 CLOSED.** libffi-exact marshaling, `import "DPI-C"` task/function + `c_name=` aliasing, output/inout copy-back, open arrays, `svdpi.h`. UVM compiles without `UVM_NO_DPI`. |
| 36 | Programming language interface (VPI) | FULL | **M12 CLOSED.** SV object model: typed variables with value-change callbacks, dynamic arrays/queues/assoc with element access, class member navigation, interfaces/modports/packages as scopes, live covergroup handles. |
| Annex A | Formal syntax | N/A | Reference grammar. |
| Annex B | Keywords | FULL | keyword sets gated by generation (`` `begin_keywords ``). |
| Annex C–L | (packages, tasks, misc annexes) | PARTIAL | `std::` semaphore/mailbox/process supported; `std::mailbox#(T)` via the `std::` prefix is a syntax error (bare `mailbox#(T)` works). |

## M14 gap closures

The audit found six remaining **silent** gaps (constructs that compiled
but produced a wrong result or no effect with no diagnostic). All are
closed:

**Fixed (real implementation):**
1. **`case (x) inside` range matching** (12.5.4) — range items collapsed
   to their lower bound; interior values never matched. Now lowered to
   the `inside` membership operator (ranges, comma-lists, singles, array
   membership). `parse.y` + `pform.cc` (`pform_make_case_inside`, guard
   duplicator).
2. **Module-static integer-keyed associative-array value read** (7.8) —
   a module-scope `int m[int]` stored via `%aa/store` but read via a
   positional darray load, always returning the default (class-member
   assoc was fine). Added the integer-key assoc read branch in
   `tgt-vvp/eval_vec4.c`.
3. **Width-1 class-property `$display`** (8) — a 1-bit `bit`/`logic`
   property took a pass-object-handle fast path (its width equalled the
   object-handle width) and printed garbage; the value itself was
   correct. Class data properties now always evaluate to a temp
   (`tgt-vvp/draw_vpi.c`). The same fix corrected `$display` of
   continuous-assign-driven interface members (clause 25).
4. **`checker`/`endchecker`** (17) — a bare "syntax error" that aborted
   the whole parse is now an explicit sorry with error recovery, so the
   rest of the source still compiles (`parse.y`).

**Converted to loud diagnostics (implementation deferred):**
5. **`randcase`** (18.16) — was a silent empty block (no branch ran);
   now a loud sorry.
6. **`std::randomize(var)` scope form** (18) — returned success while
   leaving the variable unchanged; now emits a loud one-time warning
   (kept non-fatal because UVM DV uses it as a success predicate).

## Recorded corners (M14 follow-up ledger)

- `$typename` canonical-form output; `%p` on integral aggregates.
- string/real-VALUED integer-keyed assoc reads; `int a[*]` wildcard-key
  declaration.
- Function returning an unpacked-array typedef via `'{...}` assigned as a
  whole array: no longer aborts — now a graceful `sorry` (the vvp calling
  convention still lacks an unpacked-array return path; full support is
  issue #99). The nested-literal-into-array-of-packed-struct abort is
  resolved: module-scope literals work and the class-property whole-array
  pattern store no longer silently zero-fills (issue #97 family). A
  distinct, still-open defect: class-property unpacked arrays of
  `real`/`string` store every element to one slot (issue #100).
- interface classes / `implements`; nested class declarations; out-of-body
  `extern` method bodies; net `alias`; `wait_order`; `randsequence`;
  `unique{}` constraint; `disable soft`; `unique`/`priority` **if**;
  `if/case (x matches p)` binding.
- `virtual <iface> v;` as a bare module-scope variable; wildcard-imported
  typedef used as a type; `export pkg::*` re-export; `std::mailbox#(T)`.
- `rand_mode(0)` field freeze; `process.status()`/`suspend`/`resume`.
- shallow-copy inline static initializer `C b = new a;` at module scope.
- `$root`, `$exit`, `extern module`, anonymous program, library-map files.
- timescale/timeunit conflict not diagnosed (3.14.3).

Each corner is a **loud diagnostic** (syntax error, sorry, warning, or —
for the two ICEs — an assertion abort) or a documented behavioural
limitation. None is a silent miscompile.
