# IEEE 1800-2017 Clause Conformance Matrix

Governing milestone: **M14 — IEEE 1800-2017 clause matrix with complete
disposition.** This is the authoritative clause-by-clause disposition of
the `dsellerbrock/iverilog-uvm` fork against IEEE 1800-2017.

Every disposition here is **empirical** — established by compiling and
running representative constructs against the installed simulator, not
from documentation or memory (manifesto principle 1/3). The audit that
produced it exercised each clause with positive constructs (checking
computed-vs-expected results, not merely that they compiled) and probed
for the failure modes the manifesto forbids.

## Legend

| Code | Meaning |
|------|---------|
| **FULL** | Legal syntax parses; names resolve; types preserved; runtime behaviour correct on the probed constructs. |
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
| 4 | Scheduling semantics | PARTIAL | Active/NBA/Observed/Reactive regions modeled; clocking (M8) and SVA (M9) rely on it. Formal region trace is a standing architectural item (scheduler_audit_2026_07.md). |
| 5 | Lexical conventions | FULL | sized/based/underscored literals, real/time literals, unbased-unsized `'0/'1/'x/'z`, string escapes, `` `__FILE__ ``/`` `__LINE__ ``. |
| 6 | Data types | PARTIAL | logic/bit/reg/byte/shortint/int/longint/integer/time, real/shortreal/realtime, chandle, string(+methods), event, enum(+methods), typedef, void, signed/unsigned casts, nettypes all FULL. Corner: `$typename` returns the canonical base representation (e.g. `int`→`logic`), dropping ranges — a diagnosed-by-behaviour introspection limitation, not a value miscompile. |
| 7 | Aggregate data types | PARTIAL | packed/unpacked struct & union, tagged union, multidim packed/unpacked arrays, dynamic arrays, queues, assoc arrays (string/int/object keys), assignment patterns, locator/reduction/ordering methods, streaming, `$cast`, bitstream cast all FULL. **Fixed in M14:** module-static integer-keyed assoc value read (was a silent value-loss). Corners: string/real-VALUED integer-keyed assoc (`string s[int]`) — narrow; `int a[*]` wildcard-key decl is a syntax error; `%p` on integral aggregates renders empty (has a stderr warning); member access on an element of an unpacked array of packed struct, and whole-array pattern assignment into such a class property, are fixed (were a crash and a silent zero-fill); class-property unpacked arrays of `real`/`string` still store every element to one slot (issue #100). |
| 8 | Classes | PARTIAL | new/ctor/this/super, single inheritance, virtual & pure-virtual dispatch, abstract classes, static members, const props, parameterized `#(T)`, typedef fwd-ref, protected/local, `$cast`, chained `C#(T)::m()` all FULL. **Fixed in M14:** width-1 (`bit`/`logic`) class-property `$display` (was garbage; value was always correct). Corners: interface classes / `implements`, nested class declarations, out-of-body `extern` method bodies (all syntax errors); shallow-copy inline static initializer `C b = new a;` at module scope (works as `C b; b = new a;`, and in automatic/class scope). |
| 9 | Processes | PARTIAL | initial/always/always_comb/ff/latch, final, fork/join(/any/none), disable, disable fork, wait fork, static/automatic, `process::self`/`kill`/`await` all FULL. Corner: `process.status()` reports a fixed value for a running process; `suspend`/`resume` are diagnosed no-ops. |
| 10 | Assignment statements | PARTIAL | blocking/nonblocking, continuous assign, assignment patterns, compound (`+=` etc.), `++`/`--`, aggregate assign all FULL. Corner: net `alias` (syntax error). |
| 11 | Operators & expressions | FULL | all arithmetic incl `**`, bitwise/logical/comparison/shift, `inside` (values AND ranges), `==?`/`!=?`, `?:` (incl 4-state), concat/replication, streaming, casts, string ops. |
| 12 | Procedural programming statements | PARTIAL | if/else, `case`/`casex`/`casez`, `unique`/`unique0`/`priority` **case**, for/foreach/while/do-while/repeat/forever, break/continue/return all FULL. **Fixed in M14:** `case (x) inside` range matching (was low-endpoint-only silent miscompile). Corners: `unique`/`priority` **if**, `if (x matches p)`, `case matches` tag binding (all syntax errors / diagnosed). |
| 13 | Tasks and functions | PARTIAL | task/function, automatic/static, ref/const-ref/input/output/inout, default & named args, void functions, `void'()`, class/struct/array returns, recursion all FULL. Corner: a function returning an unpacked-array typedef assigned via `'{...}` aborts (ICE — loud but ungraceful). |
| 14 | Clocking blocks | FULL | **M8 CLOSED.** default/explicit clocking, input skew (#1step Preponed), output drives, `##N`, global clocking + `$global_clock`, clocking through virtual interfaces. |
| 15 | Interprocess synchronization & communication | PARTIAL | named events (`->`/`@`/`wait`/`.triggered`), semaphores, mailboxes (incl `#(T)`) all FULL. Corners: merged events (`e1 = e2`) diagnosed; `wait_order` (syntax error). |
| 16 | Assertions (SVA) | PARTIAL | **M9 CLOSED.** Synthesized token-pipeline checkers: `|->`/`|=>`, `##N`/`##[m:n]`/`##[m:$]`, `[*N]`/`[*m:n]`, `not`/`first_match`, sampled-value functions with real histories, named properties, defaults, pass/fail actions, cover. Unsupported operators are loud sorries (recorded M9 ledger). |
| 17 | Checkers | DIAGNOSED | **Fixed in M14:** `checker`/`endchecker` now emits an explicit sorry (was a bare "syntax error" that aborted the whole parse). Not implemented; use module-bound SVA (M13 bind) instead. |
| 18 | Constrained random value generation | PARTIAL | rand/randc, `randomize()` with/without inline `with`, constraint blocks, `inside`, `dist`, implication, if-else constraints, `solve...before`, soft constraints, `constraint_mode`, pre/post_randomize, foreach constraints all FULL (class randomize). **Diagnosed in M14:** `randcase` (loud sorry — was a silent no-op); scope form `std::randomize(var)` (loud one-time warning — returns success but does not randomize). Corners: `rand_mode(0)` on a field is ignored; `randsequence`, `unique{}` constraint, `disable soft` (syntax errors). |
| 19 | Functional coverage | FULL | **M11 CLOSED.** Full clause-19 bin semantics (multi-range fixed), transitions, crosses with `binsof`/`intersect`, ignore/illegal/default, `iff` guards, options, instance & type coverage, `$get_coverage`, durable report. |
| 20 | Utility system tasks & functions | FULL | `$clog2/$bits/$size/$dimensions/$left/$right/$low/$high/$increment`, `$isunknown/$onehot/$onehot0/$countones/$countbits`, `$info/$warning/$error/$fatal`, `$time/$realtime/$stime`, math funcs, `$random/$urandom/$urandom_range/$dist_*`. (`$typename` limitation recorded under clause 6.) |
| 21 | Input/output system tasks & functions | FULL | full `$display/$write/$monitor/$strobe` format set (`%b/%h/%d/%o/%s/%c/%e/%f/%g/%t/%p/%m/%v`), file I/O (`$fopen…$fscanf/$sscanf/$fgets/$fread`), `$readmem[hb]`/`$writememh`, `$sformat[f]/$swrite`, `$value$plusargs/$test$plusargs`, `$dumpfile/$dumpvars`. (`%p` on integral aggregates recorded under clause 7.) |
| 22 | Compiler directives | FULL | `` `define `` (args), `` `ifdef/`ifndef/`elsif/`else/`endif ``, `` `include/`undef ``, stringize `` `" ``, paste `` `` ``, line-continuation, `` `line/`__FILE__/`__LINE__ ``, `` `timescale/`default_nettype/`begin_keywords/`end_keywords/`pragma/`resetall/`celldefine/`unconnected_drive ``. |
| 23 | Modules and hierarchy | FULL | instantiation (position/name/`.*`/`.name`), param overrides (order/name), `defparam`, ANSI/non-ANSI ports, hierarchical refs, `bind` (**M13**), empty/unconnected ports. Corners: `extern module`, `$root` (diagnosed). |
| 24 | Programs | FULL | program block, ports, initial/final, multiple programs. Corners: anonymous program, `$exit` (diagnosed). |
| 25 | Interfaces | FULL | interface + modport, parameters, arrays, `import`/`export` methods, clocking-in-interface, virtual interfaces as class properties (the UVM pattern), modport direction enforcement (**M5**). **Fixed in M14:** `$display` of a continuous-assign-driven interface member (shared root with the width-1 class-property fix). Corner: `virtual <iface> v;` as a bare module-scope variable is a syntax error (class-property form works). |
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
