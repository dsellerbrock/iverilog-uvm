# iverilog SystemVerilog (IEEE 1800-2017/2020) + UVM Support Status

**Repo:** `dsellerbrock/iverilog-uvm` · **Active branch:** `development`
**Assessed:** 2026-06-19 (phase work through 2026-05-11, Phase 87 `60c7a2eb5`)
**UVM library:** Accellera UVM 1800.2-2020 kit 2020.3.1 (verified at runtime via `uvm_pkg::UVM_VERSION_STRING` → `"Accellera:1800.2:UVM:2020.3.1"`)

---

## 0. Direct answer: are we "full" IEEE 1800 / "full" UVM?

**No — and it's important to be precise about what we do have.** This fork has *strong, re-verified* coverage of the SystemVerilog test corpus and the core UVM mechanisms, but it is **not a complete IEEE 1800 implementation** and it does **not yet run a full-scale UVM DV testbench to completion.**

| Claim | Honest status |
|---|---|
| Passes the full sv-tests corpus | **Yes — 1027/1027, re-verified 2026-06-19 at P87** (0 WARN-PASS / 0 FAIL / 0 TIMEOUT / 0 ERROR). |
| = "Full IEEE 1800 implementation" | **No.** sv-tests is a *sampling* corpus, not an exhaustive LRM conformance suite. Several LRM features are deferred (hard-error or stub) — see §3. There are also **active runtime fallback stubs** that degrade rather than implement — see `FALLBACKS.md`. |
| Core UVM mechanisms work | **Yes** — factory, phasing, config_db, TLM, sequences, reg layer, callbacks, coverage all exercised by 104/106 canonical tests. |
| = "Full modern UVM support" | **No.** A real OpenTitan DV testbench compiles, *starts*, and (since 2026-06-19) advances past the long-standing ~1.56 µs plateau into the real smoke sequence, where a further UVM driver/sequencer blocker surfaces (§2.3). Two canonical tests still `COMPILE_FAIL` (§2.2). |

The rest of this document quantifies that delta. The companion `FALLBACKS.md` is the authoritative inventory of compile-progress fallbacks and is the first thing to grep on any new frontier.

---

## 1. IEEE 1800 — sv-tests corpus (re-verified 2026-06-19 @ P87)

`chipsalliance/sv-tests` is the canonical SystemVerilog test corpus. Re-run command:

```bash
cd sv-tests
IVERILOG=../iverilog/install/bin/iverilog \
VVP=../iverilog/install/bin/vvp \
UVM_SRC=../iverilog/uvm-core/src \
MEM_LIMIT=$((2*1024*1024*1024)) TIMEOUT=20 JOBS=4 python3 run_iverilog.py
```

Result this run: **PASS 1027 / WARN-PASS 0 / FAIL 0 / TIMEOUT 0 / ERROR 0 / Total 1027.**

| Chapter | LRM area | Tests | PASS | Notes |
|---|---|---:|---:|---|
| 5  | Lexical conventions | 50 | 50 | full |
| 6  | Data types | 84 | 84 | full |
| 8  | Classes | 53 | 53 | interface classes / `implements` / virtual / `super` / static / parameterised |
| 9  | Processes | 46 | 46 | `process::self/suspend/resume/kill/await/status`, `->>`, `@<sequence>` |
| 10 | Assignment statements | 10 | 10 | full |
| 11 | Operators & expressions (incl. streaming) | 78 | 78 | incl. streaming pack/unpack with byte-darray operands |
| 12 | Procedural statements | 27 | 27 | full |
| 13 | Tasks & functions | 15 | 15 | extern methods, void functions, automatic |
| 14 | Clocking blocks | 5 | 5 | full |
| 15 | Interprocess sync (mailbox/semaphore/event) | 5 | 5 | full |
| 16 | Concurrent assertions (SVA) | 52 | 52 | linear sequences, `##d`, `[*N:M]`, `[->N:M]`, `[=N:M]`, `disable iff`, named reuse, composite operands (P84) — **see §3 for the deferred SVA semantics** |
| 18 | Constrained random | 134 | 134 | constraints, `dist`/`inside`/`soft`/`randc`, `constraint_mode`/`rand_mode`, `pre_/post_randomize`, array reductions, foreach constraints, `std::randomize` with-clause |
| 20 | Utility system tasks | 47 | 47 | full |
| 21 | I/O system tasks | 29 | 29 | full |
| 22 | Preprocessing | 74 | 74 | full |
| 23 | Compiler directives | 3 | 3 | full |
| 24-26 | Generate/config/packages | 4 | 4 | full |
| testbenches | UVM integration | 11 | 11 | full |
| generic | Cross-chapter | 184 | 184 | full |
| uvm | UVM smoke | 1 | 1 | full |
| **Total** | | **1027** | **1027** | **100% of corpus, honest (no vacuous PASS)** |

**Honest-accounting note.** `run_iverilog.py` classifies a vacuous PASS (compiles with a `compile-progress`/`sorry:` warning that is not equivalence-preserving, or has a success-side `:assert:` that never fired at runtime) as `WARN-PASS`, not PASS. The current 0 WARN-PASS means no *sampled* test is silently degraded. This does **not** prove the absence of fallback stubs on *un-sampled* code paths — those live in `FALLBACKS.md`.

---

## 2. UVM 1800.2-2020 support

### 2.1 Core mechanism coverage

| UVM feature | Status |
|---|---|
| Class factory, type/instance overrides | ✓ |
| `uvm_object`/`uvm_component`/`uvm_test` hierarchy | ✓ |
| Phase scheduler (build/connect/run/cleanup/report) | ✓ |
| `raise_objection`/`drop_objection` | ✓ (small tests; see §2.3 for large-TB phase-runtime frontier) |
| `uvm_resource_db` / `uvm_config_db` | ✓ |
| TLM (analysis ports, blocking, FIFOs) | ✓ |
| `uvm_sequencer`/`uvm_sequence`/`uvm_sequence_item`, `start_item`/`finish_item` | ✓ |
| Callbacks (`uvm_register_cb`, `uvm_callbacks`) | ✓ (full `m_register_pair` lazy elab) |
| `uvm_reg` register layer | ✓ |
| Functional coverage (covergroups, cross, illegal/ignore bins, dist) | ✓ |
| `uvm_table_printer` formatting | ✓ |
| `uvm_resource_pool::find_unused_resources` | ✓ |
| DPI: mixed string/int args + `output int` (UVM regex / cmdline) | ✓ (P85; x86-64 SysV only) |

### 2.2 Canonical regression — **104 / 106 PASS** (re-verified 2026-06-19)

Run: `PATH=iverilog/install/bin:$PATH bash iverilog/.github/uvm_test.sh`

104 of 106 `tests/*.sv` pass. **Two pre-existing `COMPILE_FAIL`s remain** (present on the parent commit too — not regressions):

| Test | Failure | Root cause |
|---|---|---|
| `foreach_shadow_test` | `first/next is not a method of class T` | `foreach` over a parameterised class-typed handle inside a UVM-library generic resolves the iterator methods against the unbound type parameter `T`. |
| `mutual_recursion_test` | elaboration error | mutually-recursive class/function elaboration ordering. |

> The previous version of this doc claimed "106/106" — that was an overcount. The honest number is **104/106**.

### 2.3 OpenTitan UART DV — the ~1.56 µs plateau is BROKEN (2026-06-19); a new blocker is past it

The full OpenTitan UART DV stack (`uvm_pkg` + TileLink agent + `uvm_reg` + scoreboards + DPI) **compiles cleanly and runs**. It previously **stopped advancing at ~1.56 µs** — a zero-time delta storm with ~100 K–200 K live threads parked in `cip_base_pkg::…post_apply_reset`. The earlier diagnosis (an assoc-select `wait` never waking) turned out to be **incomplete**: the plateau was actually **three independent bugs**, and the dominant one is now fixed.

**(a) The storm — `super.method()` infinite recursion [FIXED].** `super.post_apply_reset()` in the specialised `cip_base_vseq` forked **itself** instead of the empty parent `dv_base_vseq::post_apply_reset`, recursing without bound. Root cause: `netclass_t::resolve_method_call_scope` treated the empty parent body as a bodyless prototype and redirected an explicit-`super` call to the *derived* override. Fixed by binding `super.` calls statically to the named ancestor's own method (commit "super.method() binds statically to parent"). **With this fix the storm is gone and the smoke sim advances 1.56 µs → ~1.81 µs**, where it begins the real smoke vseq ("sending 5 tx bytes").

**(b) Empty assoc key `assoc[ string_darray_property[i] ]` [identified, NOT yet fixed].** OpenTitan's `cfg.m_alert_agent_cfgs[cfg.list_of_alerts[i]]` uses a key that is a string element of a `string[]` (dynamic-array) class property. `tgt-vvp/eval_string.c` (`string_ex_select` / `string_ex_property`) handles assoc/queue property elements but not darray, so the key lowers to `%pushi/str ""; ; select fallback` and the access reads `m[""]` (null). This makes the `is_active` guard read 0 and the `DV_WAIT` is skipped — so it is **not** what stalls smoke, but it is the next correctness fix for any test with active alert agents. Fix sketch: add a `%load/dar/obj/str` opcode (mirroring `%load/dar/obj/vec4`) and emit the darray-property-element path in both string lowering functions.

**(c) `wait(this.cfg.assoc[k].member)` cross-handle wakeup [FIXED, independent].** Nested-member waits reached through a class-property/`this` handle did not wake when the member was written through a different handle. Fixed in vvp (commit "wake wait(this.cfg.assoc[k].member) …"), validated by reproducers + the full sweep. **Note:** this rode along inert in OT smoke — because (b) skips the alert `DV_WAIT`, (c) is not exercised there; it is credited to the reproducers, not to the OT advance.

**New blocker past the plateau:** at ~1.81 µs the smoke vseq hits `UVM_FATAL [SQRPUT] Driver put a null response` — a separate UVM driver/sequencer response-handshake issue, the next frontier (not a regression).

---

## 3. IEEE 1800 deferred / known gaps

None of these gate a current sv-test; they are real missing features. Behaviour is noted as **hard-error** (`sorry:`, explicit refusal — safe) vs **stub** (silent degrade — see `FALLBACKS.md`).

| Gap | Where | Behaviour |
|---|---|---|
| SVA `##[N:$]` unbounded delay | `pform_sva_seq.cc` | hard-error |
| SVA `[*0:N]` empty-match start | `pform_sva_seq.cc` | hard-error |
| Multi-clock SVA | `pform_sva_seq.cc` | hard-error |
| SVA `[->N:M]`/`[=N:M]` full goto/non-consec semantics | `pform_sva_seq.cc` | approximated as `[*N:M]` (P84) — semantics not exact |
| Property/sequence local variables | parser | hard-error |
| Strong/weak property qualifiers | parser | hard-error |
| `first_match` operator | parser | hard-error |
| Open-array DPI (`type[]`), `output string`/`output real` DPI | `tgt-vvp`, DPI import | gap |
| `$dumpports` | `vpi/sys_dump.c` | upstream gap |
| `foreach` over 2D associative array | `tgt-vvp` 2D assoc codegen | gap |
| Unpacked-array `sort/rsort/reverse/unique` (some forms) | new opcodes | gap |

### Active runtime fallback stubs (silent-degrade — the real honesty risk)

These let compilation continue by emitting a placeholder instead of the real behaviour. Each is a latent correctness gap. Full inventory + source sites in `FALLBACKS.md`:

- **Expression-method stubs** (`elab_expr.cc`) — unresolved methods become `null`/`0`/`""`/queue-like placeholders.
- **Task stubs** (`elaborate.cc`) — selected unresolved UVM task calls are ignored.
- **Unresolved functor stubs** (`vvp/compile.cc`) — placeholder nets at startup.
- **Object-context null fallbacks** (`tgt-vvp/eval_object.c`, `draw_ufunc.c`) — unhandled object expressions return null.
- **UVM phase-runtime frontier** — reduced phase repro still hangs after `drop_objection` in some shapes.

---

## 4. What needs to be added (prioritised)

1. **Empty assoc key `assoc[ string_darray_property[i] ]`** (§2.3 bug (b)). Next OT correctness fix: a `string[]` class-property element used as an assoc key lowers to `%pushi/str ""`. Add a `%load/dar/obj/str` opcode + darray-property path in `tgt-vvp/eval_string.c`.
2. **OT `[SQRPUT] Driver put a null response`** (§2.3): the new blocker past the ~1.81 µs mark — UVM driver/sequencer response handshake.
3. **Close the 2 canonical `COMPILE_FAIL`s** (§2.2): `foreach` iterator-method resolution on parameterised class types; mutual class/function recursion elab order.
4. **`super.func()` static dispatch** — the expression-context twin of the 2026-06-19 task-call fix (elab_expr.cc does not yet plumb `explicit_super`); same empty-override recursion risk, not currently exercised.
3. **Retire active fallback stubs** (`FALLBACKS.md`) one by one with regression tests — convert silent degrade → real impl or honest hard-error.
4. **SVA completeness**: real `[->]`/`[=]` semantics, `##[N:$]`, multi-clock, `first_match`, property local vars.
5. **DPI breadth**: open arrays, `output string`/`output real`; portability beyond x86-64 SysV (libffi).
6. **vvp event-loop throughput** — even once §1 is fixed, large DV testbenches need scheduler perf work (P86/P87 closed two hot paths; more remain).

---

## 5. Performance notes (P86/P87)

- **P86** (`15211ec07`): `vvp_fun_anyedge_aa::pending_waiters_` short-circuit eliminates the dominant `recv_object → recover_automatic_event_context_` chain walk when no thread is waiting.
- **P87** (`60c7a2eb5`): O(1) `inbound_stacked_count_` early-out in `context_on_stacked_chain_`, removing per-`of_ALLOC` heap-set rebuilds.
- Both are correctness-preserving CPU wins on legitimate hot paths. The ~1.56 µs plateau they could not move was a **delta-cycle thread storm** (a correctness bug) — now traced to `super.method()` recursion and **fixed** 2026-06-19 (§2.3); the sim advances past it.
- Benchmark harness: `perf/run_ot_smoke_bench.sh` → one-line `commit / ns-per-s / final-ps`; history in `perf/HISTORY.tsv`.
- Full sv-tests sweep: ~5 min wall on this box (`JOBS=4`).

---

## 6. Build / run

```bash
cd iverilog
sh autoconf.sh && ./configure --enable-libveriuser --prefix=$(pwd)/install
make -j4
bash scripts/install_ivl.sh    # also installs vvp.tgt (make install misses it)

# UVM canonical regression
PATH="$PWD/install/bin:$PATH" bash .github/uvm_test.sh

# Full sv-tests (memory-guarded)
cd ../sv-tests
IVERILOG=../iverilog/install/bin/iverilog VVP=../iverilog/install/bin/vvp \
UVM_SRC=../iverilog/uvm-core/src MEM_LIMIT=$((2*1024*1024*1024)) \
TIMEOUT=20 JOBS=4 python3 run_iverilog.py
```

Wrap any long/heavy run with the memory guard to prevent runaway-process OOM:
`/tmp/memlimit.sh MEM_MB WALL_SEC -- <cmd>` (prlimit `--as` + `timeout`).
