# IEEE 1800 / UVM Conformance Roadmap — canonical execution tracker

This is the **single source of truth for what is left and in what order.**
It is deliberately built to *not drift*.

- **Detail & history** live in `iverilog_ieee1800_uvm_manifesto.md` (per-milestone
  truth status) and `matrices/ieee1800_2017_clause_matrix.md` (clause dispositions).
- **This file** holds the stable work-breakdown, the fixed ordering rule, and the
  one derived "current focus" pointer. Nothing else.

**Supersedes as a *tracking* device:** `frontier_roadmap_2026-07-17.md` and every
`session_logs/*` "Tier 1/2/3" list. Those are dated snapshots. There is exactly one
living tracker: this file. Do not introduce new Tier/Phase schemes.

---

## Why this does not churn (the anti-drift contract)

1. **The spine is the milestone set M0–M15**, taken verbatim from the manifesto.
   Milestones never renumber. Work-item IDs (below) never change.
2. **Priority is not stored — it is computed** by the fixed rule below over each
   item's *nature* + *dependencies* + *status*. There is no hand-maintained
   priority list to re-shuffle, so there is nothing to churn.
3. **Only two things ever change** in normal operation: an item's **Status**, and
   the single **Current focus** pointer at the bottom (mechanically re-derived from
   the rule, not hand-picked).
4. New discoveries **append** an item to the owning milestone; they never
   reorganize the structure.

## The fixed priority rule (do not edit)

Apply top-down; the first gate that matches wins. This restates manifesto
principle 2 + the Execution Order note, made mechanical:

1. **CORRECTNESS** — a *silent* wrong result. Always first, jumps the queue.
2. **ROBUSTNESS** — a crash / ICE (loud but ungraceful).
3. **FEATURE** — a missing but self-contained construct real testbenches hit.
4. **AUDIT** — a probe that may surface hidden silent bugs (high ROI; interleave).
5. **ARCHITECTURE** — a rearchitecture that unblocks a cluster (staged behind a flag).
6. **CAMPAIGN** — exhaustive subclause sweep / 2023 delta. Last.

**Dependency override:** an item whose `Blocked-by` names an ARCHITECTURE item
cannot start until that item lands, regardless of nature.

Every work item carries exactly one **Nature** from that list. Nature is intrinsic
to the item and does not change; Status does.

**Definition of Done:** an item is `DONE` only when it meets all 18 criteria in the
manifesto "Definition of done" section (clause identified → syntax → diagnostics →
types → elaboration → runtime → scheduling/VPI/DPI where applicable → positive +
negative + interaction tests → UVM green → baseline-clean → docs updated → committed).
The per-item "Done when" column names the *specific* acceptance beyond that baseline.

Status values: `DONE` · `PARTIAL` · `OPEN`.

---

## The spine: milestone execution order

This is the manifesto's Execution Order. It is the stable backbone; the work
breakdown that follows is grouped under it.

| # | Milestone | Area | Status |
|---|-----------|------|--------|
| — | M0 | Reproducible baseline | DONE |
| — | M1A | Typed receiver / chained dispatch | DONE |
| — | M2 | UVM factory/config/callbacks/fields | DONE (scope) |
| — | M3A | Common class constraint solving | DONE (common) |
| — | M4A | Core container runtime | DONE (core) |
| — | M6A | Core scheduler/runtime repairs | DONE (subset) |
| — | M7 | Accellera UVM qualification | DONE (harness 209/0/0) |
| — | M8 | Clocking blocks & program sched | DONE (clause-14 disposition) |
| — | M9A | Core SVA token pipeline | DONE |
| — | M10A | Core DPI imports & packed vectors | DONE (subset) |
| — | M11A | Class functional-coverage core | DONE |
| — | M12A | Core SV VPI object model | SUBSTANTIAL |
| — | M13A | Long-tail core | DONE (subset) |
| — | M14A | Clause matrix (top-level) | DONE |
| 4 | **M1B** | Specialization/aggregate typing fidelity | PARTIAL |
| 5 | **M5** | Interfaces & modports | PARTIAL |
| 6 | **M6B** | Scheduler conformance | PARTIAL |
| 6 | **M8** | Clocking reprobes | DONE (audit + disposition matrix) |
| 3 | **M3B** | Full clause-18 randomization | PARTIAL |
| 3 | **M4B** | Aggregate/container completion | PARTIAL |
| 7 | **M9B/C/D** | SVA sequence/temporal/automaton | AUTOMATON LANDED; M9-9 + M9-10 DONE; **M9-7 residual** (loud) |
| 8 | **M10B/C** | DPI completion | **COMPLETE** (all items DONE) |
| 9 | **M11B** | Coverage declaration/sampling surface | PARTIAL |
| 10 | **M12B/C** | VPI completion | **COMPLETE** (all 8 items DONE) |
| 11 | **M13B** | Long-tail tails | PARTIAL |
| 12 | **M14B** | Exhaustive subclause campaign | OPEN |
| 13 | **M15** | IEEE 1800-2023 delta | OPEN |
| — | **M1C** | Canonical semantic-IR migration | OPEN (architecture) |

---

## Work breakdown (open items only)

IDs are stable. `Nature`: C=correctness, R=robustness, F=feature, A=audit,
X=architecture, K=campaign.

### M1B — specialization & aggregate typing fidelity  (clause 6/7/8)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M1B-1 | Member access on element of static/dynamic unpacked-struct array | C | **DONE** (#106/#107) | — | static+dyn+queue member r/w + `%p`; lazy element ctor |
| M1B-2 | Struct value-copy on assignment (was reference-alias) | C | **DONE** (#108) | — | scalar/array/darray/queue `=` copy; class handle still aliases |
| M1B-3 | Remove compile-progress fallbacks caused by lost specialization | C | IN PROGRESS | — | each silent type-recovery fallback → tracked diagnostic or fix. **The `uvm_shared`/`value`/`T` fallback is gone** (R9): it was the only place in the compiler that inspected a user-visible identifier by name to decide a type, a crutch from before parameterized class properties carried concrete types. Deleting it left `get_indexed_property_type_from_base_` as just the element type of whatever the property is; validated with a full UVM run and the full ivtest suite |
| M1B-3a | Type-parameter aggregate property unusable via methods (elaboration-order) | C | **DONE** | — | queue/darray/assoc type-parameter property usable via built-in methods |
| M1B-4 | Adversarial parameterized-UVM specialization regressions | A | **DONE** | — | multi-spec suite (widths/truncation, class+struct type params, nesting, per-spec statics, param inheritance) all correct (sv_param_spec_audit) |
| M1B-5 | Partial write (bit-select / part-select / struct-member) to a class property was broken | C | **DONE** | — | RMW bit/part-select + indexed part-select (`+:`/`-:`, constant & run-time offset) + packed-struct-member writes to class properties, across elaboration (typed `set_part`), codegen (`%store/prop/v/bits` + new `%store/prop/v/bits/x`) and runtime (cobject RMW). Descending vectors fully supported; ascending-variable/multi-dim loudly rejected (sorry). sv_class_property_partial_write + negative test |

**M1B-3 audit note (2026-07-22).** Surveyed the compile-progress /
type-recovery fallbacks. **M1B-3a is now FIXED.** The defect was an
elaboration-ORDER bug (not queue- or type-specific, as the first bisection
suggested): a class property typed as a type parameter bound to an
aggregate (queue/darray/assoc) was unusable through its built-in **methods**
because the method-target path
(`elaborate_nested_method_target_property_task_`, elaborate.cc) resolved it
with `property_idx_from_name()`, which returns -1 when the specialization's
property has not yet been committed (properties are declared on demand). The
method call was then mis-dropped as an "unknown task" and the aggregate
silently stayed empty. Indexing worked because it goes through the
`NetEProperty` expression path, which already forces `ensure_property_decl()`
— so the fix routes the method-target path through the same
`ensure_property_decl()`. Regression:
`ivtest/ivltests/sv_typeparm_aggregate_property.v` (queue/darray/assoc
method access). The other surveyed fallback sites (elab_lval.cc,
t-dll-proc.cc, the enum-through-macro path in elab_expr.cc) already emit a
loud "compile-progress fallback" diagnostic — they are tracked, not silent.
Follow-up: the UVM-specific hack `infer_indexed_property_type_fallback_`
(net_expr.cc, hardcoded to `uvm_shared`/`value`/`T`) patches the *indexed*
type-inference path for the same underlying shape and may now be removable
— left as a separate tracked cleanup pending its own UVM validation.

**M1B-3 capability probe (2026-07-24).** The hack triggers only on the
literal class name `uvm_shared`, so the discriminator is whether the same
shape works under a *different* name. Probe m1b3_generic declares
`class my_shared #(type T)` with property `value` specialized to a queue
and to a dynamic array, and exercises `push_back`, `size()`, indexed read
and indexed write through it — all correct. The general path
(`ensure_property_decl()` via `NetEProperty`) therefore already resolves
the shape, and the hardcoded fallback is very likely dead code.
**Remaining terms for M1B-3:** delete `infer_indexed_property_type_fallback_`
and its single call site (net_expr.cc:73), then validate with a full UVM
run (212/212) — a full run is the only evidence that can retire a
UVM-specific hack.

### M4B — aggregate/container completion  (clause 7/21)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M4B-1 | Struct value-copy through method args / return / `push_back(var)` | C | **DONE** | — | by-value struct arg, by-value return, and `push_back(var)` each snapshot rather than alias — verified and pinned by sv_struct_value_copy_args (the row was stale; the behavior already worked) |
| M4B-2 | Nested unpacked-struct **deep** copy (current copy is shallow) | C | **DONE** | — | assigning a nested unpacked struct deep-copies the inner struct — verified and pinned by sv_struct_value_copy_args (the row was stale) |
| M4B-3 | Adversarial nested-container testing | A | **DONE** | — | queue-of-struct, struct-of-darray, assoc-of-queue, class-of-queue-of-struct verified; array-of-queue is a loud sorry (known); the partial-write bug (M1B-5) surfaced here too |
| M4B-4 | `%p` on packed struct → `'{member:val}` (prints one decimal) | F | OPEN (deferred, cosmetic) | — | packed struct prints member pattern |
| M4B-5 | `%p` nested unpacked dims print nested not flat | F | OPEN (deferred, cosmetic) | — | multi-dim prints `'{'{..},..}` |
| M4B-6 | Partial write to a packed-vector member of a plain (unpacked) STRUCT variable (`s.byte_en[z]`, `s.data[i +: 8]`, constant & run-time offset, incl. nested structs) was silently miscompiled (whole-member store) | C | **DONE** | — | unpacked-struct members are cobject-backed and share the M1B-5 read-modify-write path (typed `set_part` → `%store/prop/v/bits`[`/x`]); the class-member elaborator no longer drops the sub-member index for struct owners. sv_struct_member_partial_write |
| M4B-7 | **Compound assignment** (`|=`, `+=`, …) into a partial class-property/struct-member select crashed vvp (a regression the M1B-5/M4B-6 RMW opcodes introduced: the binary opcode had no LHS operand) | C | **DONE** | — | codegen now loads the current field (`%prop/v`+`%parti/u`, or `%part/u` for a run-time offset) and pads the r-value to the field width before the op; constant & run-time offset, single-bit, width-mismatched r-value all correct. Found by the write-path audit; sv_class_property_partial_write |
| M4B-8 | Partial write to a **virtual-interface struct field** (`vif.pkt.a = …`, `vif.pkt.b[3:0] = …`) silently miscompiled (whole clobber / dropped) | C | **DONE** | — | two causes: (1) an interface-local typedef failed to resolve when the vif property type was elaborated in a disposable scope that carried only parameters (not typedefs) → member degraded to a 32-bit integer; fixed by registering the interface's typedefs. (2) a bit/part-select ON a packed-struct field was discarded (whole-field store); fixed by composing the field base offset with the sub-select — also fixes the same defect on class packed-struct-field selects. sv_vif_struct_field_write |
| M4B-9 | Member write into an **associative-array element** of an unpacked struct (`m[key].d = …`, part-selects & compound too) was silently dropped for a not-yet-present key (whole element read back 0) | C | **DONE** | — | root cause: object-backed queue/assoc signals never recorded their element class type (only darrays did), so the l-value load pushed a discarded default. Now the `.var/queue` record carries the element type (like `.var/darray`), and a new `%aa/loadlv/sig/obj/*` opcode get-or-CREATES + inserts the element on the write path (reads still don't insert; class-handle elements stay null). sv_assoc_elem_member_write |
| M4B-10 | Slice/part write to a **multi-dimensional packed** class property/member (`r.m[1] = …`, `r.m[i][j] = …`, `r.m[i][7:4] = …` where `m` is `logic [3:0][7:0]`) was a loud `sorry` | F | **DONE** (constant indices) | — | leading constant bit indices map through `prefix_to_slice` to a canonical LSB-0 offset/width, narrowed by an optional trailing part-select on the innermost dimension; 2-D and 3-D slice/bit/part forms verified, incl. multi-dim struct members. VARIABLE multi-dim indices remain a loud sorry (honest residual). sv_multidim_packed_prop_write |

### M4C — READ-path partial-select arc (r-value duals of M1B-5/M4B-6..10; from the 179-probe read-path audit, 24 double-verified findings)

| ID | Item | Class | Status | Blocked-on | Verification |
|----|------|-----|--------|-----------|-----------|
| M4C-1 | R-value bit/part/indexed select of a packed-vector CLASS PROPERTY: 4-state crashed vvp (`property_logic::get_vec4` assert — select base mis-encoded as property ARRAY index `%prop/v/i`), 2-state silently read zeros, multi-dim used only the first index, chained-handle selects (`o.inr.v[3:0]`) silently dropped, vif flat-member selects wrong | C | **DONE** | — | selects of vector properties now elaborate as `NetESelect` over the whole-property read with canonical LSB-0 offsets (constant + variable, `+:`/`-:`, multi-dim, ascending/descending) via `make_vector_property_select_`; three sites patched (main member elab, nested chained-base helper, chained-index walker). sv_class_property_partial_read |
| M4C-2 | Indexed struct-member READ through a class-property chain printed a NON-FATAL `sorry` (exit 0), yielded x, and if-conditions const-folded to the wrong branch | C | **DONE** | — | chain walker now builds the member read then applies the canonical vector select (`make_vector_property_select_`); unsupported forms are a FATAL sorry. sv_struct_member_partial_read |
| M4C-3 | Bit/part-select READ of unpacked-struct vector members returned x/0 (plain variable and container elements); `[b -: w]` read as `[b +: w]`; `$display` arg became a blank | C | **DONE** | — | three silent-nil/stub sites fixed (check_for_struct_members, the two container-element member-index lambdas — one raw-base, one make_nested_stub); all route through the canonical vector select; assign/$display/compound/if contexts verified. sv_struct_member_partial_read |
| M4C-4 | OOB READ of a queue-of-struct element GREW the queue (regression from M4B-9's queue `declared_type`) | C | **DONE** | — | `of_LOAD_DAR_OBJ` lazy materialization bounds-guarded to `adr < size` (IEEE 7.10.2: OOB queue read returns default, must not modify); in-bounds queue/darray materialization unchanged. sv_struct_member_partial_read |
| M4C-5 | Nonexistent-assoc-key member reads returned 0 instead of x for 4-state; queue/darray ELEMENT tail selects (`q[i][m:l]`) silently returned the whole element and `[b -: w]` was mis-based; nested unpacked-array property chain reads (`o.inr.arr[i]`) dropped the element index (read x) | C | **DONE** | — | null-receiver property fallback pushes all-x for IVL_VT_LOGIC (new draw_pushi_all_x, chunked >32b); darray/queue element tails route through the canonical vector select; the chain walker passes indexed components into the nested helper for ARRAY-typed properties (NetEProperty canon_index -> %prop/v/i) instead of post-applying a whole-array NetESelect. sv_container_elem_read_defaults |
| M4C-6 | Multi-dim packed OOB residuals from md-adversary | C | **DONE** | — | ascending-range element read/write verified fixed by M4C-1/M4B-10; struct/property OOB element writes are a loud sorry; inner-bit OOB writes are a no-op (no neighbor spill); the plain-var constant OOB element write ICE (sb_to_slice assert) is now a warned no-op per 11.5.1/7.4.6. sv_multidim_oob_write |
| M4C-7 | Re-verification of the 12 usage-limit-orphaned audit findings | A | **DONE** (triaged) | — | REAL+FIXED: compound/plain ops on part-selects of fixed unpacked-array elements crashed vvp (width-mismatch) or applied to the whole element and stored at offset 0 — slice loader/store now part-aware, const+dynamic word/part (sv_array_word_part_compound). ALREADY-FIXED by the M4C arc: queue-elem part write abort, container [m:l] reads, vif base-0 reads, assoc part-write drops. STILL OPEN below: M4C-8, M4C-9 |
| M4C-8 | NBA through a class handle or virtual interface executed immediately (blocking semantics) — silent event-region violation (4.9.3, 10.4.2) | C | **DONE** (whole-property vec4) | — | new `%assign/prop/v` opcode + NBA-region scheduler event (`schedule_assign_prop_vec4`): receiver+value captured at statement execution, store applies in the NBA region; supports `#delay`, last-write-wins ordering, 2-state cast, null-handle no-op, interleaving with signal NBAs. Residual forms (partial-select / indexed-property NBA, event/repeat controls) degrade to blocking WITH a loud codegen warning (honest, tracked). sv_nba_class_property |
| M4C-10 | `automatic event` / `static event` block declarations are a bare syntax error (IEEE 6.17/6.21); plain `event e;` in blocks works. Lifetime-prefixed grammar attempts added +43 s/r conflicts — needs a factoring that shares the variable-decl prefix, or per-activation event runtime (the real arc) | F | OPEN (loud, tracked) | — | hunt finding (h5); `wait fork`, fork/join_any/none, disable fork, semaphore/mailbox/process class all verified correct in the same battery |
| M4C-11 | `v inside {obj.q}` with a queue/darray CLASS PROPERTY as the container silently compared the value against the container handle (always false); plain-signal containers worked | C | **DONE** | — | non-signal darray/queue-typed items in the `inside` item list route to the runtime membership test via new `%inside/arr/o` (container popped from the object stack); the codegen fallback that force-pushes 0 is now loud. Deep chains, `this.q`, empty/null containers, mixed value+container lists verified. sv_inside_property_container |
| M4C-12 | Queue-of-queues silently unusable: queue LITERALS as method args (`qq.push_back({1,2})`) compiled to a null push (inner elements lost, nested ops on the element silently dropped); whole-assignment `qq = {{1},{2,3}}` mis-spliced the element literals through queue-concat and read objects out of vec4 queues; FLAT splices `q = {q1, 5, q2}` vec4-coerced the queue operands to garbage | C | **DONE** | — | array patterns of queue/darray type build real containers in object context (new `%dup/obj/ref` alias dup + element stores; `%append/qo/{v,r,str,obj}` object-stack splice); shape-aware element-vs-collection classifier (10.10) shared by the queue pattern assign path, which now splices vec4/real/string element queues via new `%append/qobj/{v,r,str}`; mutation ops on null/mismatched queue receivers warn loudly. sv_queue_of_queues |
| M4C-13 | Queue slice `q[a:b]` CRASHED elaboration (packed part-select assert on empty packed dims); `%p` on queue-of-queues ABORTED vvp (object elements read as garbage vectors); `%p` of container-valued expressions printed -1/`<object>` | C | **DONE** | — | new `$ivl_queue$slice` lowering + `%qslice` opcode (element-kind generic, clamped bounds, inverted→empty, fresh copy); `vvp_format_cobject_p` renders container values recursively (queue-of-queue elements, container class properties); VPI args of whole-container expression type pass as object handles. sv_queue_slice_p |
| M4C-14 | Assoc-of-queue CLASS PROPERTIES silently unusable: `c.aq[key].push_back(v)` dropped the mutation (nil element, no vivify — loud only since M4C-12's null-receiver warning); values stored with the wrong element kind (strings drawn as vec4); `c.aq[k].pop_front()` elaborated to a silent CONSTANT 0 (width-query give-up → CLASS stub → elab_and_eval short-circuit); deep-chain double-index reads (`h.c.iq[k][i]`) dropped the trailing index | C | **DONE** | — | new `%aa/loadlv/o/q/{obj,str,v} "<enc>"` get-or-create loads + property-rooted vivify branch in the queue receiver; element kind derived from the select's base container; test_width clears the indexed flag for container-element targets (mirrors dispatch); nested property reads consume trailing indices through container elements, residue is a loud sorry. sv_assoc_queue_property |
| M4C-15 | `mailbox #(string)` CRASHED the runtime (message boxed as vec4 string-bits, get() stored through recv_vec4 → abort); `mailbox #(real)` messages silently bit-mangled | C | **DONE** | — | vvp_boxed_string/vvp_boxed_real wrappers + `%box/{str,real}` / `%unbox/{str,real}`; item push/store codegen dispatches on string/real type in task and expression contexts (string LITERALS matched via IVL_EX_STRING). sv_mailbox_string_real |
| M4C-16 | Streaming to/from FIXED unpacked arrays was a loud reject both directions (`{>>byte{arr}} = word` failed the cast check; `{>>byte{arr}}` r-value errored "needs an array index"); class-property array operands packed silently WRONG | F | **DONE** | — | netuarray target branch unpacks the stream into an array pattern (MSB-first, `<<` inverse reorder, leading-bits consume, descending ranges map to canonical positions, too-small stream is a loud error); whole-array operands (plain signals AND class properties) pack as declared-order element concats; dynamic-operand-into-fixed-target is a loud sorry. sv_stream_unpacked_array |
| M4C-9 | Member writes into assoc elements of packed-struct type ABORTED iverilog; bit/part writes to vec4 assoc elements were silently dropped (misrouted to the int-indexed darray path); `[b +: w]`/`[b -: w]` on darray/queue/assoc elements was a sorry; the `%aa/loadk/v/*` keep-key load peeked the receiver at the wrong obj-stack depth (latent vec4-key crash) | C | **DONE** | — | elaboration lowers container-element member writes to word(key)+part(member range) and indexed part-selects to canonical offsets; codegen RMWs assoc elements via `%aa/loadk` + new `%setbits/vec4[/x]` + `%aa/store`; keep-load depth fixed. Deeper member selects (`pm[k].a[3:0]`, `pm[k].b[7]` lvals) compose the member offset with the constant sub-select. sv_assoc_elem_partial_write |

### M5 — interfaces & modports  (clause 25)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M5-1 | Modport member visibility (read + write) | C | **DONE** | — | listed-only access; CE tests |
| M5-2 | Interface-member change-sensitivity (all r-value forms) | C | **DONE** | — | bare/indexed/operator/multi/mixed, both edges |
| M5-3 | Runtime-index vif-array binding `vp[i]=pins[i]` in a loop | F | **DONE** | — | synthesized instance-dispatch mux (ternary of NetEScope handles); out-of-range→null |
| M5-4 | Bare `$unit`-scope `virtual iface v;` (parse error today) | F | **DONE** | — | dedicated package_item alternatives; $unit + package scope, incl. vif arrays |
| M5-5 | Generic `interface` ports | F | **DONE** | — | `interface i` / `interface.mp i` formals get a placeholder type at elab_sig and are retyped per instance from the ACTUAL in a PGModule pre-pass BEFORE the child body elaborates; the existing vif binding then connects. One generic module binds different interfaces per instantiation; modport actuals and one-level formal forwarding work (scope-direct bindings init before forwarding ones); non-interface and unconnected actuals are loud errors (negative-tested); deeper forwarding chains fail loudly at t0. sv_generic_interface_port |

**M5 status note (2026-07-22).** M5-1/2/3/4 are DONE. **M5-5 (generic
`interface` ports) is a materially larger feature than the other M5 items**
and stays open as its own arc. Confirmed by investigation: an interface
type resolves by NAME (`interface_type_t::elaborate_type_raw` looks it up in
`pform_modules`), a generic port has no name, and the module body (`ifp.d`)
elaborates against the port's declared type *before* any instantiation
connection is known. Supporting it needs **per-instantiation port typing** —
resolve the port's interface type from each connection during the instance's
scope-elaboration phase and elaborate the body against it (like a
type-parameterized module) — which reworks module-elaboration order that all
instantiation depends on. The current behavior is a **loud, actionable
`sorry`** (points the user at the typed-port form), so there is no
silent-miscompile gap; it is deferred rather than rushed.

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M3B-1 | `randcase` / `std::randomize(var)` / `unique {}` | F | **DONE** | — | tests landed |
| M3B-2 | `randsequence` | F | **DONE** | — | productions/sequences/nesting/weighted alternatives via source-level expansion; recursion/reuse is a loud sorry |
| M3B-3 | `disable soft` | F | **DONE** | — | soft constraints on the named variable dropped for the randomize() call |
| M3B-4 | Reaudit `rand_mode` / `constraint_mode` combinations | A | **VERIFIED WORKING** | — | Probe m3b4_randmode: object-level and per-field `rand_mode()`/`constraint_mode()` set and query, in all combinations, behave correctly. **Terms:** pin the probe as a regression test, then close |
| M3B-5 | Seed-stability + failed-randomization state tests | A | **DONE** (RNG half) | — | **Fixed the P0:** `srandom()` and `set_randstate()` elaborated to an empty `NetBlock` and `get_randstate()` returned a literal empty string, so seeding silently did nothing — re-seeding one object with seed 7 gave 103 then 198, and two objects seeded identically diverged (probe m3b5_seed_stability). **Fix:** each `vvp_cobject` carries its own RNG and each `vthread_s` carries the process RNG (18.13.2) — xorshift64*, one 64-bit word, so `get_randstate()` is that word and `set_randstate()` reads it back exactly; 18.13.3 leaves the string implementation-defined, and a tagged prefix (`ivl1:` / `ivlp1:`) lets a foreign string be rejected loudly. New `%srandom` / `%get_randstate` / `%set_randstate` opcodes dispatch on object vs. `process`. `randomize()` draws from the object RNG, and per 18.13.1 so do `$urandom`/`$urandom_range` — via a new `vpip_object_urandom()` hook the vpi/ module consults before its own generator, resolving the enclosing object first, then walking the thread's parent chain for a seeded process. Reproducible for unconstrained *and* constrained properties (the solver starts from the same draws). Unqualified in-method `srandom()`/`get_randstate()` resolve through `this`. UVM's `p.get_randstate()`/`p.set_randstate()` save-restore idiom works. **Deliberate boundary:** a generator activates only once SEEDED; unseeded objects and threads keep drawing from the global generator, so every unseeded sequence — and each gold depending on one — is bit-for-bit unchanged (ivtest 1024/1068, full UVM confirm). **Note:** `process p = process::self();` as a *static* declaration initializer captures the wrong process (it is hoisted to a separate init thread); Icarus already warns on that form — use `automatic` or assign inside the block. The fail-state audit half of this row is separate and covered by M3B-6. tests m3b5_object_random_state_test, m3b5b_swrite_return_var_test |
| M3B-7 | `$swrite`/`$sformat` into a function's return variable wrote nothing | C | **DONE** | — | Discovered while landing M3B-5, and it had to be fixed for UVM to run at all. The target is an output argument, but a function's return variable cannot be passed to a VPI call as a signal (`draw_vpi.c` falls back for `signal_is_return_value()`), so it went across as a read-only copy on the string stack: `vpi_put_value` updated that copy, the call popped it, and nothing committed it to the return slot — a **silent** empty result. Elaboration now rewrites `$swrite(f, fmt, ...)` to `f = $sformatf(fmt, ...)`, the same operation through the path that does work. UVM's `uvm_instance_scope()` (uvm_misc.svh) does `$swrite(uvm_instance_scope, "%m")` and then walks backwards from `len()-1`, so the empty string started the walk at -1 and looped without bound. It had been unreachable because its only caller arrives via `uvm_object::reseed()` -> `srandom()`, and srandom's empty-block elaboration discarded the ARGUMENT along with the call — so making srandom real is what first executed it. test m3b5b_swrite_return_var_test |
| M3B-6 | `x inside {q}` container-property constraints + honest randomize() failure | C | **DONE** | — | queue/darray property containers expand against live contents at solve time (`q:IDX:EWID` IR + solver support); empty container unsatisfiable; item-level IR drops fail loudly; %randomize/%randomize-with return 0 on UNSAT and restore pre-call rand values (18.6.1); solver UNKNOWN stays lenient but loud; with-form solves inherited base constraints. sv_constraint_inside_container |

**M3B-2 note.** `randsequence` is lowered by source-level expansion from
the start production: sequences become blocks, alternatives become a
weighted `PRandCase` (the same lowering as `randcase`), code blocks and
non-terminals expand in place. Because pform statements cannot be
duplicated, each production is expanded at most once; a production
referenced more than once or a recursive grammar is a **loud sorry** (needs
a task/automaton lowering — future work). No silent-miscompile gap.
Advanced production features (`rand join`, `repeat`/`case` productions,
production value/args, `break`/`return`) are not yet parsed.

### M6B — scheduler conformance  (clause 4)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M6B-1 | Per-instance class events; process suspend/resume/status | F | **DONE** | — | tests landed |
| M6B-2 | Post-NBA VPI callback region (cbNBASynch) | F | OPEN (loud) | M6-CALLF | `cbNBASynch` is **not defined in `vpi_user.h` at all**, so a VPI app that registers it fails to *compile* — loud, not silent. The existing sync regions do work and all fire after NBA settle, in the order cbReadWriteSynch → cbAtEndOfSimTime → cbReadOnlySynch (probe m6b2b). **Terms:** define `cbNBASynch` (IEEE 1800-2017 clause 38 reason code), add a scheduler queue drained immediately after the NBA queue and before the existing RWSync point, and accept the reason in `vpi_register_cb`/vvp/vpi_callback.cc dispatch |
| M6B-3 | Scheduling for time-consuming DPI imports | F | **VERIFIED WORKING** | M6-CALLF | An imported `context task` consumes simulation time via the coroutine path, and it participates in normal scheduling: `fork`/`join_any` + `disable fork` correctly abandons a blocked DPI import and its exported task never completes (probe m6b3_kill). **Terms:** pin the probe as a regression test, then close |
| M6B-4 | Assertion attempt-lifecycle scheduling | F | **PARTIAL** — preponed sampling complete (whole signals + selects); region placement untouched | ARCH M9-NFA | **Fixed the P0:** concurrent assertions sampled **Active**-region values instead of **Preponed** (IEEE 1800-2017 16.5.1), so a blocking write in the same time slot as the clock was visible to the assertion and the verdict flipped, silently. Repro (probe m6b4_det): one thread does `a = 1; clk = 1;`; `assert property (@(posedge clk) a \|-> b)` must sample the preponed `a` (=0) and be vacuous, but Icarus saw `a`==1 and reported a failure. NBA-written operands only looked right because NBA updates land after edge detection — nothing sampled. **Fix:** the synthesized checker now reads each whole-signal operand through `$ivl_clocking_sample` (lowers to `%load/preponed`) with a matching `$ivl_clocking_hist_on` prologue — reusing the 1-deep driven-value history built for clocking-block `#1step` inputs (14.13) rather than adding a scheduler region. The wrap is applied before the sampled-value rewrite, so `$past`/`$rose` history chains capture preponed values too (16.9.3). Two latent bugs in that sysfunc surfaced and are fixed with it: it had no `test_width` case (argument width 0 → zero-width read) and no elaboration typing (default 32-bit vs the `%load/preponed` operand width → `val_size >= wid` abort in `of_STORE_VEC4`), and a non-signal argument such as a parameter emitted **no code at all** for the operand (`peek_vec4` stack underflow — `sv_checker_bind`); a constant's preponed value is now simply its value. **Select operands now sample too (R1 closed):** `%load/preponed` reads a whole signal, so elaboration builds the select over the *sampled whole signal* — a `NetESelect` wrapping `$ivl_clocking_sample`. Bit-selects, part-selects, indexed part-selects and descending vectors all sample like a whole signal, verified by comparing each against a whole-signal control under blocking writes in the clock's own time slot (pre-fix the selects read live and the assertions wrongly PASSED). **Remaining (loud, not silent):** hierarchical/package-qualified names, unpacked-array words, reals, and expression shapes the copier cannot clone still read live — all four now warn, where the last three were silent before, see R11. Per-attempt start/step/end region placement is the other half of this row and is untouched. tests m6b4_assert_preponed_sample_test, sv_assert_select_preponed_sample; probes m6b4_det, m6b4_sample, m6b4_nba, m6b4_selbound |

### M8 — clocking blocks (DONE — clause-14 disposition matrix)  (clause 14)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M8-1 | Reprobe edge-qualified skew forms | A | **DONE** | — | input/output `#N` skew timing verified & pinned (sv_clocking_skew_audit) |
| M8-2 | Reprobe real/string/aggregate clockvars | A | **DONE** | — | packed sample correctly; real/string/unpacked-array are a loud `sorry`→alias (disclosed) |
| M8-3 | Parameterized vif clocking stress | A | **DONE** | — | non-param vif clocking verified; parameterized vif is a loud warning (tracked repro) |
| M8-4 | Clocking + program + assertion + VPI ordering stress | A | **DONE** | — | region ordering + program end-of-sim (24.7) pinned (sv_program_clocking_finish) |
| M8-5 | Every clause-14 subfeature has a disposition | K | **DONE** | — | `docs/conformance/m8_clocking_disposition.md` |

### M9 — SVA  (clause 16/17)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M9-1 | Bounded liveness/safety `nexttime[n]`,`eventually[m:n]`,`always[m:n]` | F | **DONE** (PR #109) | — | windowed lowering + tests |
| M9-2 | Abort operators `accept_on`/`reject_on`/`sync_*` | F | **DONE** (PR #109) | — | boolean-operand sampled gating + tests |
| M9-3 | Property combinators `implies`/`iff`/`if-else`/`case` property | F | **DONE** (PR #109) | — | boolean-combinator lowerings + tests |
| M9-4 | Goto / nonconsecutive repetition `b[->n]` `b[=n]` | F | **DONE** (NFA C.1) | — | plain-seq + `##N` + `\|=>` consequent; `##0`-fused `\|->` consequent is a loud sorry corner |
| M9-5 | Local sequence variables `(a, v=e) ##1 (b && f(v))` | F | **DONE** (NFA LV-1/LV-2) | — | fixed + variable-delay per-slot storage |
| M9-6 | `.matched` / complete `.triggered` / strong-weak sequences | F | **DONE** (NFA C.2/C.3) | — | endpoint methods + strong/weak obligation |
| M9-7 | Multiclock sequences | F | **PARTIAL** (D.1 + D.2 + D.3) | — | `\|=>` CDC with FIXED-length chains on both sides done (D.2): the antecedent chain pipelines in the c1 domain (one attempt per tick, request counter on match), the consequent chain pipelines in the c2 domain from the first strictly-after tick (mid-chain failures fail at their own tick); overlapping attempts, `##N` gaps, vacuous passes verified. **Multiclocked `cover property` and `disable iff` now work (D.3)**, both on the same handoff: a cover counts consequent matches into `_ivl_sva<inst>_cnt0` — the identical register name the legacy and automaton engines use, so a test reads the count the same way whatever produced it — and builds no fail action at all, since an unmatched consequent is a non-match rather than a verdict; `disable iff` clones its condition into both domains (it is a level, read at each domain's own ticks) and, while it holds, clears the c1 stages without bumping `req` and makes the c2 side swallow the outstanding obligation, so an aborted attempt neither passes nor fails. Verified by comparison, not by its own number: the cover count moves opposite the assert's failure count on the same stimulus, `disable iff (0)` is indistinguishable from no disable, `disable iff (1)` lets nothing escape, and a windowed reset aborts exactly the attempts inside it while attempts after it clears resume. **Remaining loud errors:** mid-sequence clock flow (`@(c1) a ##1 @(c2) b`) — now a *named* sorry pointing at the `\|=>` form that works, where it used to be a bare "syntax error / Malformed statement"; the grammar recognises the shape only to say so, at zero conflict cost. Cross-clock `\|->`, whose at-or-after coincidence is not lowerable behaviorally (two always blocks on the same edge have undefined relative order — see R12). Variable-length CDC operands, which need an automaton in the second domain. tests/sva_nfa multiclock_chain; sv_assert_multiclock_cover_disable; negative sva_multiclock_ov, sva_midseq_clock_flow |
| M9-8 | Variable-length `intersect` / `within` | F | **DONE** (NFA B.2/B.4) | — | non-fixed operands over the automaton |
| M9-9 | `checker`/`endchecker` (clause 17) | F | **DONE** (module-like subset) | — | Checkers ride the module machinery (the grammar folds `K_checker`/`K_endchecker` into the module rule, zero new bison conflicts): typed formals with directionless-defaults-to-INPUT (17.4), default formal values, property/sequence decls, `assert`/`assume`/`cover`, checker-local `default clocking` (verified functionally — an assertion with no explicit clock fires), internal variables and procedures, multiple instances with independent assertion state, `endchecker` labels, keyword-mismatch diagnostics, and **a checker instantiated inside another checker** (verified against a direct-instantiation control driven by the same stimulus, so an inert nested instance would show up as a count mismatch). **Corrections to this row:** it previously listed nested-checker instantiation as a residual, citing `tests/negative/m14_checker_unsupported` — but that test covers a different thing, a checker DECLARED inside a module (the nested-module scoping limit, still correctly rejected). And it omitted free variables. **LOUD residuals:** untyped formals, event-typed formals, free (`rand`) variables (17.9), a checker declared inside a module, procedural instantiation — all four probed and confirmed loud. sv_checker_basic, sv_checker_nested_instance, sv_checker_bind; negative m14_checker_unsupported, checker_free_variable |
| M9-10 | Procedural concurrent assertion forms | F | **DONE** | — | Implicit clock inference (16.14.6) is implemented: an `assert`/`assume`/`cover property` with no clocking event and no default clocking is **parked** at parse time and takes the clock of the innermost enclosing procedural event control, so `always @(posedge clk) assert property (a \|-> b)` works with no explicit clock. The inference happens with **no grammar change** — bison reduces `event_control` before its statement, so the controlling event already exists when the assertion reduces; the conflict baseline stays 494 s/r + 1161 r/r. A sibling event control *cannot* adopt an assertion it does not lexically enclose (checked by source position), and nested event controls resolve innermost-first. Default clocking still wins where declared. **This row also fixed a P0 silent miscompile it was sitting on top of:** a concurrent assertion synthesizes its own always block and state variables at parse time, and inside a `begin`/`end` those went into the block's `PBlock` — whose `behaviors` nothing elaborates, and which the `seq_block` rule `delete`s outright when it holds no declarations. So `always @(posedge clk) begin assert property (@(posedge clk) a \|-> b); end` — with an *explicit* clock, ordinary SystemVerilog — registered the assertion and then never evaluated it, reporting no failures and no diagnostic. The lowering now runs against the nearest enclosing non-block scope. sv_assert_procedural_implicit_clock, sv_assert_in_procedural_block; negative assert_unclocked_no_enclosing_event, assert_unclocked_sibling_always. **LOUD residual:** nothing enclosing at all (`initial assert property (p);`, or a module-item assertion) is still the 16.14.6 error — see R10 |
| M9-11 | `expect` statement | F | **DONE** | — | the process blocks on a single inline attempt: fixed `##N` chains unroll to clock-waits (both engines); windows, repetition, goto, unbounded `##[1:$]`, and or/and/intersect trees drive the sequence automaton inline (per-state 1-bit registers advanced per tick; first accept = pass, empty next set = fail) — no M6-CALLF dependency needed. Residual loud sorries: implication/strong/weak/negation/multiclock/`disable iff`/local-variable expects, and any shape under IVL_SVA_LEGACY=1. tests/sva_nfa expect_fixed_chain (dual-run) + expect_general_nfa_only |

**M9 status note (corrected 2026-07-22).** The **M9-NFA per-attempt
automaton engine is LANDED and is the default SVA engine** — stages
A/B/C/D.1 all shipped in prior sessions (design doc
`m9_nfa_design_2026-07-19.md`), verified by `tests/sva_nfa/run.sh`
(dual-run 33/33: automaton vs legacy verdict-parity, plus nfa-only golds).
M9-4/5/6/8 are therefore DONE via the automaton; M9-7 is PARTIAL (the
`|=>` CDC handshake works, harder multiclock forms are loud errors). The
boolean-collapse operators M9-1/2/3 (PR #109) fill in the pieces the
automaton doesn't need. **Every M9 residual is a LOUD rejection — there is
no silent-miscompile gap anywhere in clause 16.** The genuine remaining
frontier WAS **M9-9 (checker/endchecker, clause 17)** — now landed as the
module-like subset — leaving the M9-7 multiclock residuals, the
`##0`-fused goto-consequent corner, and eventual legacy-engine retirement.

### M10B/C — DPI completion  (clause 35)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M10-1 | Multidimensional open arrays (`svGetArrElemPtr2/3`) | F | **DONE** | — | 2-D/3-D element access, and **fixed-size array marshaling with declared-range reporting**. A fixed array is not an object, so using one where an object is wanted — `d = a` (7.6) or a DPI open-array actual (35.5.6.1) — needs a dynamic-array copy of its words; tgt-vvp pushed element 0 instead, so both silently produced an **empty** array. New `%load/arr/dar` makes the copy, with the element kind packed as a NUMBER because `vvp_code_s` keeps `array` and `text` in one union (a string operand silently clobbered the resolved array pointer — it segfaulted immediately). The **declared range** survives the copy: `vvp_darray` carries an optional left/right, `vvp_dpi_open_array_t` carries it into the handle, and `svLow`/`svHigh`/`svLeft`/`svRight`/`svIncrement` report it — so `int a[3:10]` gives low 3 / high 10 / incr +1 and `int a[10:3]` gives left 10 / right 3 / **incr −1**. `svGetArrElemPtr1/2/3` translate the **declared** index to the canonical word (H.10.3); without that the fixed bounds would have made a `for (i = svLow; i <= svHigh; i++)` loop read wrong elements and run off the end — a worse bug than the one being fixed. Earlier `svIncrement` (hardcoded −1) and `svSizeOfArray` (0 for multidim) fixes are folded in here. tests m10_dpi_fixed_array_marshal_test, m10_dpi_open_array_bounds_test |
| M10-1b | The `arr[i]` reads-element-0 claim was a misreading | — | **RETIRED** | — | The claim came from a hardcoded `%ix/load 3, 0, 0` in tgt-vvp. An indexed element read is `IVL_EX_SIGNAL`, whose path evaluates the word index properly; `IVL_EX_ARRAY` is by API definition the whole array with **no index**. Indexing was already correct and is now pinned across constant, variable, expression and descending indices, write-through, queues, dynamic arrays and string-keyed associative arrays. The defect on that path was real but different — see M10-1c. test sv_class_array_element_index |
| M10-1c | Whole unpacked array used as a single class handle was silently accepted | C | **DONE** | — | `h = arr;` and `f(arr)` — both type errors (7.4/8.3) — compiled as `arr[0]`. Now rejected in `elaborate_rval_expr`, the one place that sees BOTH the whole-array rvalue and the single-handle target type. tgt-vvp cannot: it sees the same `IVL_EX_ARRAY` expression for this and for the **legal** `C q[]; q = arr;`, so a codegen check had to either reject the legal form or accept this one. Catching it at elaboration unblocked class-handle element marshaling, so `q = arr` now works with handles copied by reference; the error also lands on the user's assignment instead of in codegen. Argument passing is an assignment to the formal, so it goes through the same check. A codegen sorry remains as the backstop for element types that still cannot be marshaled (strings, structs). tests m10_dpi_fixed_array_marshal_test; negative object_array_to_handle, object_array_as_handle_arg |
| M10-2 | DPI export (C→SV) | F | **DONE** | — | `export "DPI-C"` was already implemented end-to-end (parse → pform resolve → t-dll → tgt-vvp directives + a generated `.dpiexport.c` stub → the vvp `__ivl_dpi_export_call_*` dispatcher); the row was stale. Verified working: int/real/string/void returns and args, renamed (`c_name =`) exports, multi-instance and context exports, and time-consuming exported tasks via the coroutine path when reached from an imported DPI *task*. **Fixed a crash found by probing the boundary:** a time-consuming export reached from an imported DPI *function* has no coroutine to park on — the inline runner spun the child past its delay and joined it while the scheduler still held a future event, aborting vvp on assert(is_scheduled) (then assert(children.empty())). The runner now stops when the child delays, emits the existing loud sorry, and detaches the child so it completes under the scheduler. tests m10c/d/e/f + new m10g_dpi_export_blocking_diag_test |
| M10-3 | Real context semantics / `chandle` ABI verification | A | **DONE** | — | Probing showed this already worked, so it is now pinned rather than fixed: `chandle` round-trip through an import and through an **output** formal, `chandle` stored in a class property and in an unpacked array and read back, `real` and `int` through **inout** formals, `string` through an output formal. test m10j_dpi_chandle_abi_test |
| M10-4 | Time-consuming imported tasks | F | **DONE** | **M6-CALLF** | An imported `context task` consumes time via the coroutine path, and a time-consuming exported task reached from it runs across simulation time (probe m10_4_slowtask). **Fixed one P0 silent wrong result found by probing the boundary:** an export declared with **`automatic` lifetime** received **`x` for every argument**, even on a single non-concurrent call, so a value-returning export returned garbage and `#(d)` degenerated to a zero delay -- with no diagnostic. **Root cause:** `compile_export_dpi` (vvp/compile.cc:1250-1263) resolves `arg_nets` once at link time to the **static prototype nets**, and `dpi_export_run_` (vvp/vthread.cc) marshaled into them with a null context; an automatic body reads its per-invocation frame and never sees those nets. The dispatcher now allocates a context for an automatic export and marshals into it -- the same shape `%alloc` gives an ordinary SV call -- and hands it to the child, which owns it so `release_owned_context_` frees it on the inline, coroutine and orphaned-detach paths alike. This also makes **concurrent** invocations of one automatic exported task correct, each keeping its own arguments. **Correction:** an earlier probe read concurrent aliasing of a *static* export as a second defect; it is not. IEEE 1800-2017 13.3.1 gives a static subroutine one copy of its arguments, so concurrent invocations alias -- verified identical for a plain SV static task (probe staticsem), and deliberately preserved. Nested automatic frames inside the exported body and recursive C -> export -> C -> export re-entry both verified (probes m10_4g_nested, m10_4h_recurse). tests m10h_dpi_export_automatic_test + m10i_dpi_export_automatic_nested_test |
| M10-5 | C→SV→C reentrancy + cross-platform DPI regressions | A | **DONE** (Linux; CI covers the rest) | M10-2 | Two-deep reentrancy `c_outer → sv_mid → c_inner → sv_leaf` returns the correct value with each SV frame entered exactly once. Already worked; now pinned. The macOS and MSYS2 legs of CI cover the cross-platform half on every push. test m10k_dpi_reentrancy_test |

### M11B — coverage surface  (clause 19)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M11-1 | Package-scope covergroups | F | **DONE** | — | standalone covergroups declare a class type whose netclass IS the covergroup (bins as own properties); `new` instantiates; coverpoint sources elaborate at each sample site in the caller's scope. sv_covergroup_standalone |
| M11-2 | Module/interface-scope covergroups | F | **DONE** | — | module_item grammar (+0 bison conflicts), explicit sample()/crosses/iff/per-instance state, and declaration sampling events (`covergroup cg @(posedge clk);`) synthesizing per-instance `always @(ev) inst.sample();` processes. Ctor formals on standalone covergroups are parsed but ignored (loud). sv_covergroup_standalone |
| M11-3 | Complete sampling-event forms | F | **DONE** | — | standalone forms complete (`@(edge sig)`, or-lists, plain any-change). Class-embedded `covergroup cg @(ev);` (was a hard parse error) now samples every live instance on the event: a static per-scope process runs `%covgrp/sample/all` over the runtime instance registry, reading coverpoint source and iff-guard values from each instance's parent object properties through a hidden parent handle (auto-linked when the covergroup object is stored into the parent's property). Per-instance guards, mid-sim creation, coexistence with explicit sample(), dropped handles all verified. Residual loud gap: an event coverpoint not backed by a parent property records constant 0 with a sorry. sv_covergroup_class_event |
| M11-4 | `with function sample` formal semantics | F | **DONE** | — | formals bind positionally/by name to sample() arguments at each call site (module/package/class scope); formal shadows scope signal or parent property; iff-guard formals, crosses, arity/name mismatch loud errors. Also fixed: package ctor-parens covergroups silently collected nothing (stub class shadowed the real one). Residual loud gap: a formal inside an expression coverpoint (`coverpoint (m+1)`) samples constant 0 with a sorry. sv_covergroup_with_sample |
| M11-5 | Coverpoint-expression + option/type_option audit | A | **DONE** | — | audit fixed two silent-wrong classes: automatic bins for non-parent-property sources (standalone signals, sample() formals, expressions) were spread over 2**32 (every sample piled into bin 0) — now sized from the source type/width; enum coverpoints get one auto bin per named value (19.5.1) at all scopes. option.detect_overlap now reports overlapping bins at compile time; at_least/weight/auto_bin_max verified end-to-end; procedural `inst.option.X` reads were silent 0 — now a loud sorry (writes already loud); remaining accepted-no-effect options (goal, comment, name, per_instance, cross_num_print_missing, type_option.*) are reporting metadata. sv_covergroup_options |
| M11-6 | Coverage serialization/interchange + adversarial cross/transition | A | **DONE** | — | durable text report (IVL_COVERAGE_REPORT env; type-level counters, per-bin hit/MISS) verified; adversarial audit fixed two defects: ignore_bins/illegal_bins values now carved out of the coverpoint's other bins and the cross product (19.5.5 — a fully-carved bin inflated the denominator and could never be hit), and duplicate per-scope class compiles left zero-count registry orphans that dragged $get_coverage toward 0 (registry now dedupes by dispatch prefix, newest wins). Multi-step transitions, per-instance NFA state, and binsof cross routing verified correct. sv_covergroup_adversarial |
| M11-7 | Chained covergroup method calls (`obj.cg.sample()`) | F | DONE | — | sample/guard values read from the covergroup's parent object, not the caller's `this`; chained + cross-object sites correct |

### M12B/C — VPI completion  (clause 36/38/40)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M12-1 | Assertion start/step/disable lifecycle callbacks | F | **DONE** | — | every cbAssertion* reason is delivered: Start/Success/Failure from the NFA checkers, Disable/Enable/Reset from the global control tasks, and (new) StepSuccess/StepFailure — the slot advance sets per-tick step flags (a live slot reaching the continue branch advanced a step; the dead_busy branch died mid-sequence) dispatched like the pass/fail flags, and the runtime points `detail.step` at a step-info record. Documented boundary: a step report covers every attempt that stepped that tick (matching the existing per-tick Success/Failure aggregation), so the matched-expression list and stateFrom/stateTo are zeroed rather than guessed; the legacy engine (IVL_SVA_LEGACY=1) delivers every reason except the step pair. ivtest vpi m12_assert_step (VPI 91/91) |
| M12-2 | Populate `s_vpi_attempt_info` | F | **DONE** (fixed-latency) | — | attemptStartTime now recovers a completing attempt's REAL launch tick, not the fire time. A fixed-latency loop-free automaton (pform_sva_nfa_fixed_latency: unique start→accept edge count) makes every attempt take the same ticks, so the runtime keeps a ring of recent cbAssertionStart times (depth_arg threaded compile→$ivl_register_assertion→__vpiAssertion) and reports the completing attempt's start from `latency` ticks back — correct even for pipelined attempts (verified: `a\|=>b` fails at t15 reporting start t5). Same-tick assertions report now (exact). Residual: variable-latency (`##[m:n]`, `##[1:$]`), cyclic, and legacy/multiclock checkers report the completion tick (documented); failExpr stays 0 (no SVA sub-expression handle model). **Corrected during M12-1:** the ring was also being applied to plain-sequence FAILURES, where an attempt can die at its FIRST step — that misattributed an older launch to it. The checker now passes a `fail_full_latency` flag (set for implications, whose unobligated attempts die silently), so failure start-times are recovered only where every reported failure ran the full latency; plain-sequence failures report the failing tick, which IS the start of an early death. sv m12_assert_attempt (VPI 91/91) |
| M12-3 | Bit-select force/release + cbForce/cbRelease | F | **DONE** | — | vpi_put_value(vpiForceFlag/vpiReleaseFlag) on a single bit-select handle (sig[i]) was a loud sorry (part-select ranges already worked); now forces/releases that one bit as a width-1 case of the part-select path (unforced bits seeded with the live value). cbForce/cbRelease callbacks can now register on a bit-select handle (vpiNetBit/vpiRegBit) — they attach to the parent signal's filter and fire on force/release. Procedural bit/part-select force + whole-signal VPI force were already correct. ivtest vpi m12_bit_force (VPI 90/90) |
| M12-4 | Associative-array element writes via VPI | F | **DONE** | — | vpi_put_value on positional element handles (key order, mirroring the read path): the entry keeps its key, the existing entry supplies the value kind and vec4 width (a 32-bit vpiIntVal put into a byte element truncates); int/scalar/vector puts into vec4 maps, real (and int-converted) into real maps, string into string maps. Loud rejections: mismatched formats, object-valued elements, out-of-range positions. ivtest vpi m12_assoc_write (VPI suite 84/84) |
| M12-5 | Nested class-member traversal | F | **DONE** | — | dotted-path vpi_handle_by_name walks object-valued members at any depth (was one level), vpiMember iteration recurses into object members, vpiFullName composes through the chain, and handles re-fetch the live object through the parent chain on every access — a handle stays valid (and follows the FRESH subtree) after any object along the path is re-assigned. Null intermediates are gracefully handle-less. ivtest vpi m12_nested_members (VPI suite 85/85) |
| M12-6 | Modport direction/access metadata | F | **DONE** | — | each interface modport's port list flows elaboration→ivl_scope_modport_port_{name,dir}→extended .modport directive→VPI: vpi_iterate(vpiIODecl, modport) yields per-port handles with vpi_get(vpiDirection) (input/output/inout; ref→vpiNoDirection), vpiName/vpiFullName composition, vpiSize = port count. vpiIODecl assigned code 604 in sv_vpi_user.h (IEEE's 25 collides with Icarus vpiIntegerVar). ivtest vpi m12_modport_dirs (VPI suite 87/87) |
| M12-7 | Covergroup drill-down handles | F | **DONE** | — | vpi_iterate(vpiCoverpoint/vpiCoverCross) on a covergroup object (standalone variable or nested class member), vpi_iterate(vpiCoverBin) per item; item handles expose the coverpoint/cross label (plumbed compile→.covgrp_item→runtime), at_least/weight, bin count, and per-item instance coverage (vpiRealVal); bin handles expose instance and type-merged hit counts. Constants documented in sv_vpi_user.h (Icarus extension — IEEE defines no covergroup VPI model). ivtest vpi m12_covgrp_drill (VPI suite 86/86) |
| M12-8 | VPI object lifetime/free behavior | A | **DONE** | — | audit of the M12 handle families: found and fixed a per-call leak in the covergroup drill-down (M12-7) — item and bin handles were `new`'d fresh on every vpi_iterate and never stored; now cached per (root, defn, kind) / per item so repeated iterate returns identical handles (verified stable), living for the simulation like member handles. Confirmed safe: member/nested-member/modport handles are container-owned; vpi_free_object on a suppress_free handle is a no-op (no double-free); a handle whose backing object is dropped to null reads vpiSuppressVal, not a crash (live re-fetch through the root). ivtest vpi m12_lifetime (VPI suite 88/88) |

### M13B — long-tail tails  (clause 23/28/31)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M13-1 | Bind to specific instance path | F | **VERIFIED WORKING** | — | Probe m13_1_bind_instpath: functionally checked, not just parsed — the bound checker observed the correct value from its target instance. **Terms:** pin the probe as a regression test, then close |
| M13-2 | Bind target-instance lists | F | **VERIFIED WORKING** | — | Probe m13_2_bind_instlist: list-target bind reaches every named instance. **Terms:** pin the probe as a regression test, then close |
| M13-3 | `config` semantics + library mapping | F | OPEN (loud) | — | Unimplemented and diagnosed with a sorry — no silent-miscompile risk. **Terms:** real config/library resolution |
| M13-4 | `trireg` charge semantics | F | OPEN (loud) | — | Unimplemented and diagnosed with a sorry — no silent-miscompile risk. **Terms:** charge decay model |
| M13-5 | `$nochange` / `$timeskew` / `$fullskew` | F | **DONE** (row was wrong) | — | All three are implemented and **fire on violation**, together with `$width`, `$period`, `$setup`, `$hold`, `$recovery`, `$removal`, `$recrem` and `$setuphold` (probe fires: violations reported for `$width`@12/18, `$period`@16/28, `$nochange`@48, `$fullskew`@48, `$timeskew`@48). Unsupported *shapes* are a loud sorry, e.g. `$nochange` with non-zero start/end offsets. **The earlier accepted-noop reading was a probe error:** the whole specify block -- path delays and timing checks alike -- is inert without `-gspecify`, which is the established opt-in contract, and the probes had omitted the flag. Re-probed with `-gspecify` and the checks work |
| M13-6 | Timing-check edge-descriptor lists + timestamp/timecheck conds | F | **DONE** | — | Edge descriptors select which transitions arm a check, and `&&&` conditions gate the body. **Fixed a real silent defect found by probing this functionally rather than by parse:** the synthesized previous-value tracker was written only from an `always @(sig)` block, which never runs at time 0, so it sat at the `x` sentinel until the first transition -- and that transition therefore matched no descriptor. The failure mode was worse than ignoring the descriptor: for a signal starting at 0, `$setup(edge[01] d, ...)` reported **nothing** where plain `$setup(d, ...)` reported the violation, so adding a descriptor silently discarded a real violation. The tracker is now primed at time 0 from the signal's own value. `edge[01]`, `edge[10]` and multi-entry lists all verified to select exactly the right transitions. test sv_timing_check_edge_descriptor |
| M13-7 | `pulsestyle` / `showcancelled` | F | OPEN (loud) | — | `pulsestyle_onevent`/`pulsestyle_ondetect`/`showcancelled`/`noshowcancelled` are accepted and have no effect on pulse propagation. This was already loud under `-gspecify`, but the warning read "Timing checks are not supported" -- naming the wrong construct entirely, since these are pulse-filtering controls. The message now names the specific directive and says pulse filtering is not modelled, so cancelled and short pulses propagate as usual. **Terms:** model pulse filtering in the path-delay engine (reject/error limits, cancelled-pulse propagation) |

### M14B — exhaustive subclause campaign  (all clauses)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M14B-1 | Correct stale FULL labels; re-evaluate FULL rows with corners | K | OPEN | — | matrix labels match reality |
| M14B-2 | Downgrade clauses 19/31/35/36 to reflect gaps | K | OPEN | — | honest dispositions |
| M14B-3 | Subclause-level evidence + link rows to permanent tests | K | OPEN | — | every row has a test link |
| M14B-4 | Adversarial/generated silent-miscompile hunt; zero-silent-gap policy | K | OPEN | — | generated sweep clean |

### M15 — IEEE 1800-2023 delta  (2023 spec)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M15-1 | 2023 delta scoping + clause matrix | K | OPEN | M14B, all P0/P1 | delta enumerated |

---

## Architecture big rocks (unblock clusters; staged behind flags)

These are the only items that gate large downstream clusters. Land them in order;
each behind its existing feature flag with the named litmus suite as the gate.

- **ARCH-1 · M9-NFA** — NFA-based sequence matcher replacing the flat linear token
  chain. **Unblocks:** M9-4…M9-10, M6B-4, M12-1, M12-2. *Recommended first big rock*
  (lower risk than the scheduler; unblocks the most distinct features). Stage:
  thread model → local vars → repetition → strong/weak → multiclock, behind the
  existing linear path so nothing regresses. Gate: full SVA suite + negative SVA.
- **ARCH-2 · M6-CALLF** — scheduled-call / function-atomicity protocol
  (`IVL_SCHED_CALLF`, currently flagged off). **Unblocks:** M10-2 (DPI export),
  M9-11 (`expect`), M10-4 (time-consuming DPI), M6B-2/M6B-3 (post-NBA VPI).
  Higher risk; sequence *after* ARCH-1. Gate: the race/region litmus suite.
- **ARCH-3 · M1C** — canonical semantic-IR migration (type descriptor, typed lvalue
  + aggregate-layout interfaces, bypass-path inventory). Foundational and
  cross-cutting; do as narrow, test-guarded conversions **interleaved** whenever a
  nearby silent type-recovery fallback (M1B-3) is touched — never as a big-bang.

Dependency graph (arrows = "unblocks"):

```
ARCH-1 M9-NFA ──▶ M9-4,5,6,7,8,9,10 · M6B-4 · M12-1,2
ARCH-2 M6-CALLF ─▶ M10-2 (DPI export) · M9-11 (expect) · M10-4 · M6B-2,3
ARCH-3 M1C ──────▶ (reduces M1B-3 silent-fallback risk; interleaved)
```

---

## Compliance scorecard (measurable, clause-level)

From `matrices/ieee1800_2017_clause_matrix.md` (M14A, top-level of 36 clauses).
Several PARTIAL rows are now *stale-conservative* (fixed after the matrix was
written); M14B-1 will reconcile them.

| Disposition | Count | Meaning |
|-------------|-------|---------|
| FULL | 21 | core + probed subfeatures correct |
| PARTIAL | 15 | core correct, specific corners recorded |
| DIAGNOSED | 3 | loud, not implemented (e.g. checkers) |
| N/A | 4 | informative/organizational |

**Honest headline:** ~90% of the common / UVM-relevant IEEE 1800-**2017** surface
works correctly (UVM 209/0/0, no known silent miscompiles). The residual is
*concentrated* in three places — advanced SVA (M9-4…M9-10, needs ARCH-1),
DPI export + multidim open arrays (M10-1,2, export needs ARCH-2), and checkers
(M9-9). Full standards-complete compliance is **not** claimed and cannot be
certified until **M14B** (subclause audit) closes. IEEE 1800-**2023** (M15) is ~0%,
deliberately gated.

---

## Current focus (the only mutable ordered list — derived from the rule)

Re-derive this by applying the priority rule to the OPEN items above; do not hand-edit
the structure. The partial-write correctness arc is now fully closed — both the class-
property form (M1B-5) and its unpacked-struct-member sibling (M4B-6). No known silent
miscompiles outstanding; the frontier is again bounded FEATURE + AUDIT work.

Recently retired (this arc): **M12B/C VPI completion — the whole
milestone** (assertion lifecycle + step callbacks, meaningful
`s_vpi_attempt_info`, bit-select force/release, assoc-element writes,
nested class-member traversal, modport metadata, covergroup
drill-down, lifetime/free audit) · **M11B coverage — the whole
milestone** (standalone covergroups, `with function sample`, option
audit, ignore/illegal carving, class-embedded sampling events) ·
M9-11 (`expect`) · M9-7 D.2 (multiclock fixed-length chains) · M5-5
(generic interface ports) · M9-9 (checkers) · M4B-1/M4B-2 (verified
already-correct and pinned by a test).

Complete milestones: M0-M8, **M10**, M11, M12. (M9 is one row short: M9-7 multiclock is PARTIAL with a loud residual. M9-10 procedural forms landed, and closing it surfaced a P0 — an explicitly clocked assertion inside a `begin`/`end` was silently dropped.)

**Capability analysis of all open items (2026-07-24).** Every open item
was probed for what it *actually* does rather than what its row claimed.
The ordering below is the re-derived result. Nine rows were stale in both
directions: six items already worked (M13-1, M13-2, M3B-4, M6B-3, M10-3,
M10-5) and three silent defects were hiding under "OPEN" rows that read as
merely unimplemented (M3B-5, M6B-4, M10-4, plus M13-5/6/7 as
accepted-noops). All three of those are now fixed; M13-5/6/7 remain. The lesson that drove this sweep holds: **probe
boundaries, not headline features** — every headline worked.

1. **P0 silent wrong results — these preempt everything** (rule gate 1):
   - ~~**M10-4** `automatic`-lifetime DPI exports read `x` for every
     argument~~ — **FIXED**; the dispatcher now allocates a per-invocation
     frame. This also made concurrent automatic exports correct.
   - ~~**M6B-4** concurrent assertions sample **Active**, not
     **Preponed**, values~~ — **FIXED** for whole-signal operands, which
     is the common case. A bit/part-select operand still reads live and
     now says so with a compile-time warning, so the residual is loud.
   - ~~**M3B-5** `srandom()`/`set_randstate()` are silent no-ops~~ —
     **FIXED**; per-object RNG, and `$urandom` in a method follows it.
   - ~~**M10-1** object-array element load ignores its index~~ —
     **misdiagnosed** (M10-1b retired; indexing was already correct). The
     real defects were a whole fixed array used as an object yielding an
     EMPTY array, and a whole array silently accepted as a single class
     handle. Both fixed (M10-1, M10-1c). **M10 has no open items.**
2. **M13-5/6/7 accepted-noops** — timing checks, edge descriptors and
   `pulsestyle`/`showcancelled` are accepted and silently ignored. Under
   the loud-sorry rule an accepted-noop ranks above ordinary unimplemented
   work, and a tracked diagnostic is a small change.
3. **Pin the six verified-working items** (M13-1, M13-2, M3B-4, M6B-3,
   M10-3, M10-5) with their probes as regression tests and close them.
   Cheap, and it stops the rows from going stale again.
4. **M6B-2** — define `cbNBASynch` and give it a post-NBA queue. Already
   loud (undefined macro → user compile error), so it is ordinary work.
5. **M13-3/M13-4** — `config` + library mapping, `trireg` charge decay.
   Both already loud sorries; real feature work.
6. **M9-7 residuals** — mid-sequence clock flow (parse error), cross-clock
   `|->` (loud sorry); needs engine support, not synthesis.
7. **M1B-3 / M4C-10 / M4B-4,5** — delete the now-dead `uvm_shared` hack
   (needs a full-UVM run to retire), the automatic-event parse gap, and
   the deferred cosmetic `%p` forms.
8. **M14B** subclause campaign → **M15** 2023 delta (CAMPAIGN; last).

**Standing override:** any newly discovered silent miscompile or crash preempts this
list (rule gates 1–2).

---

## Residual register

Every **partial** fix leaves a residual. This is the one list of them, so a
row marked DONE or PARTIAL above cannot quietly read as complete.

**Rule:** a residual is acceptable only while it is LOUD (a sorry, an error,
or a warning naming the case). A residual that is silently wrong is a rule-1
defect and preempts the ordered list above. The `Loud?` column is therefore
the thing to check first.

**A residual leaves this table only by being fixed, or by being shown to have
nothing to fix — never by being re-described.** The second exit was added
deliberately, because the table had started to accumulate rows recording
*decisions* rather than work: a construct the LRM makes illegal, a clause
with no clock to offer, a lowering strategy that cannot be built
behaviorally. Those are conformance limits, not debt, and leaving them here
made the list grow every time a milestone was touched. They move to
**Settled limits** below, and closed rows move to **Closed**. Nothing is
deleted; the numbers never get reused. What remains in this table is work
someone still has to do.

| # | Residual | From | Loud? | What closing it takes |
|---|----------|------|-------|------------------------|
| R2 | Per-attempt assertion start/step/end **region placement** is unimplemented; only the sampled values were fixed. | M6B-4 | n/a — not wrong, absent | The other half of the M6B-4 row |
| R3 | An object's / process's RNG activates only once **seeded**; an unseeded one draws from the global generator rather than one derived from its parent process (18.13.1). | M3B-5 | n/a — deliberate, documented | Seed each object's RNG *from the process RNG* at construction, and each thread's from its parent at `fork`. Doing so changes every unseeded sequence, so it needs a gold-rebaseline decision first — that is why it is deferred, not difficulty |
| R4 | A **static** declaration initializer (`process p = process::self();`) is hoisted to a separate init thread, so it captures the wrong process. | M3B-5 (pre-existing) | **yes** — Icarus already warns that the form needs an explicit lifetime | Evaluate a static initializer in the declaring block's thread, or narrow the warning into an error for `process::self()`. `automatic` and in-block assignment both work today |
| R6 | `pulsestyle_*` / `showcancelled` are accepted and have no effect on pulse propagation. | M13-7 | **yes** — per-directive warning naming the construct and what is not modelled | Model pulse filtering in the path-delay engine (reject/error limits, cancelled-pulse propagation) |
| R8 | `%p` prints a packed struct as a plain integer and flattens nested dimensions. | M4B-4/5 | no — cosmetic | Deferred by decision, not by difficulty |
| R11 | Two operand shapes still read live: a **hierarchical or package-qualified** name (the history enable is emitted into the checker's own scope and cannot reach another one), and an operand the Preponed read cannot reach at the far end — an **unpacked-array word** (`%load/preponed` takes a signal and ignores the word index, so sampling one would read word 0) or a **real** (no `%load/preponed` form exists). A third, an expression shape the copier cannot clone, makes the whole guard fall back to live. | M6B-4 / R1 | **yes** — the first and third get a per-assertion warning naming the count and the reason; the second gets a per-operand warning at elaboration. Before closing R1 all three were silent | Array words need a word-indexed preponed load (a new opcode); reals need a real-valued one; hierarchical names need the history enable emitted into the target scope. Each is a runtime addition, not a rewrite fix |

### Settled limits (nothing to implement)

Kept enumerated and numbered so a reference to them still resolves, and so
re-opening one is a visible decision rather than a rediscovery.

| # | Limit | From | Loud? | Why there is nothing to do |
|---|-------|------|-------|-----------------------------|
| R5 | A time-consuming export reached from an imported DPI **function** is unsupported. | M10-2 | **yes** — sorry | Nothing: illegal for value-returning functions, and no coroutine exists to park on |
| R10 | Implicit clock inference takes the innermost **enclosing** event control. Where nothing encloses the assertion at all — a module-item `assert property (p);`, or `initial assert property (p);` with no `@` — it stays an error. Conversely the inference accepts shapes 16.14.6 leaves as errors (an assertion preceded in the procedure by another timing control still takes the enclosing clock), which is a superset: no conformant design is mis-clocked, and the clock taken is always one written lexically around the assertion. | M9-10 | **yes** — error naming 16.14.6, and it names the absence of an enclosing event control specifically | For the `initial`/module-item case, nothing: 16.14.6 has no clock to offer there. For exact rather than superset conformance, reject inference when a preceding timing control disqualifies it — deliberately not done, because erroring on a shape whose intended clock is unambiguous is worse for users than accepting it |
| R12 | Cross-clock **overlapping** implication `@(c1) a \|-> @(c2) b` is rejected. 16.13.3 wants the consequent to start at a c2 tick coincident with the antecedent match, and two `always` blocks triggered on the same edge have undefined relative order, so any behavioral lowering picks a winner by luck. | M9-7 | **yes** — sorry naming the construct and the `\|=>` form that works | Nothing behavioral. It would take the two domains fused into one evaluation body driven by both edges, which is a different lowering strategy from the request/ack handoff — recorded as a design limit, not a TODO |

### Closed

| # | Was | From | — | How it closed |
|---|-----|------|---|----------------|
| R1 | ~~A bit/part-select assertion operand reads its **live** value~~ | M6B-4 | — | **CLOSED.** A select is now sampled by taking the whole signal's Preponed value and applying the select to *that* (`NetESelect` over `$ivl_clocking_sample`, built in elaboration where the operand's type is known), so bit-selects, part-selects, indexed part-selects and descending vectors all sample like a whole signal. Pinned by sv_assert_select_preponed_sample, which compares each select against a whole-signal control under blocking writes in the clock's own time slot — against the pre-fix compiler it printed `bit=0 part=0 whole=2`, i.e. the selects read the new value and the assertions wrongly PASSED. Closing it surfaced two more live-read paths in the same rewrite that were **silent**, now loud — see R11 |
| R7 | ~~svdpi open-array bounds and fixed-array marshaling~~ | M10-1 | — | **CLOSED.** Bounds report the declared range (including descending, increment −1), element access translates the declared index, and fixed arrays of integral/real elements marshal. What is left is narrower and has its own row: a fixed array of **class handles** used as an object, a loud sorry pending an elaboration-time type check — see M10-1c |
| R9 | ~~The hardcoded `uvm_shared`/`value`/`T` type-inference fallback~~ | M1B-3 | — | **CLOSED.** Deleted, along with the now-unused parameters of `get_indexed_property_type_from_base_`, which reduces to the element type of whatever the property is. It was the only place in the compiler that inspected a user-visible identifier by name to decide a type — a compile-progress crutch from before parameterized class properties carried concrete types. Validated with a full UVM run plus the full ivtest suite: nothing depends on it |

**No residual in the open table is silently wrong any more. R1, R7 and R9 are
closed outright.** R7 took three passes: the two hardcoded bounds accessors, then
the declared-range plumbing, then the declared-index translation that the
bounds fix made necessary (without it a standard
`for (i = svLow; i <= svHigh; i++)` loop would have read the wrong elements
— fixing half of a pair like that is worse than fixing neither).

Every remaining entry is loud, deliberate, or cosmetic, which is the bar the
loud-sorry rule sets. That does not make the list finished; it makes it
honest. One pattern is worth keeping in view: **three of the entries here
were narrowed or corrected only when someone ran a discriminating test
against them**, and two turned out to be misdiagnosed outright.

**The split into open / settled / closed was itself a correction.** The
table had been growing: closing a residual reliably turned up one or two
more, and some of what got written down was not work at all but a decision
already made — R5 (illegal per the LRM), R10 (16.14.6 has no clock to offer
where nothing encloses the assertion), R12 (a coincident cross-clock start
is not lowerable behaviorally when two `always` blocks on the same edge have
undefined relative order). Recording those as debt made the list read as
though it were losing ground when it was not. They are now enumerated
separately, and the open table is six rows of real engineering: **R2**
assertion region placement, **R3** RNG derivation (blocked on a
gold-rebaseline decision, not on difficulty), **R4** static-initializer
process capture, **R6** pulse filtering, **R8** `%p` formatting (cosmetic,
deferred by choice), **R11** word-indexed and real preponed loads. Plus one
milestone residual with no register row of its own: M9-7's variable-length
cross-clock operands.

**R6 was corrected, not closed by wishful thinking.** It previously read
"timing checks, edge descriptors and pulse controls parse, elaborate and are
silently ignored", and that was simply wrong: the whole specify block is
inert without `-gspecify` and the probes behind the claim had omitted the
flag. With the flag, the timing checks are implemented and fire, and the
pulse controls were already warned about. Probing the family properly
*did* turn up a real silent defect, but a different and narrower one --
the unprimed edge-descriptor tracker, now fixed under M13-6 — which is the
second time a residual entry has paid for itself by being re-examined
rather than trusted.

**Both R6 and R7 turned out to be misdiagnosed**, and in the same way: each
was written from reading a code comment or a hardcoded constant instead of
running a discriminating test. Re-examining them found a real silent defect
in each case, but a *different and narrower* one than the entry described --
the unprimed edge-descriptor tracker (M13-6) and silent acceptance of an
illegal whole-array-to-handle assignment (M10-1b). The lesson is the one this
tracker keeps relearning: **a claim about behaviour needs a test that would
fail if the claim were false**, and reading the source is not that test.

**Retired from this list:** the original R3 — `process::srandom()` rejected
with a sorry — was closed by being implemented rather than re-described,
within M3B-5 itself, once UVM proved the reject was the wrong call (UVM's own
save/restore idiom uses it). Two of the residuals here were found *by fixing
another one*
(R4 and M3B-7 both surfaced while landing M3B-5), which is the argument for
keeping the list: a partial fix reliably exposes the next defect underneath
it.
