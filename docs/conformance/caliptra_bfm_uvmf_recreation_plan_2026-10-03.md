# Caliptra BFM / UVMF recreation plan — 2026-10-03

**Status: PLAN (Level 3 operational proposal). It authorizes no implementation.**
Only `.ai/ACTIVE_WORK.yaml` authorizes implementation work. Each work item
below must be selected there, one at a time, per `AGENTS.md`. This document is
not a conformance status source and does not change any matrix entry.

**Evidence basis.** The Caliptra checkout is **not present in this
container**. Every statement tagged `[repo]` is taken from committed evidence
in this repository. Every statement tagged `[unverified]` is recalled from
public knowledge of UVMF/Questa VIP and **must be confirmed in Phase 0**
against the pinned checkout before anything is built from it. Do not treat
`[unverified]` rows as requirements.

Pinned sources `[repo: release_overlays/README.md]`: Caliptra `v2.1.2`
`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`; Adams Bridge `v2.0.3`
`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`.

---

## 1. What "the needed BFM" actually is

The word covers two different gaps. They have different owners and must not be
conflated.

### Track A — L0 integration lane (firmware-driven, `caliptra_top_tb`)

The BFMs are **already in the pinned tree** and compile: `caliptra_top_tb_soc_bfm.sv`,
`axi_if.sv` (task-bearing AXI BFM interface), `caliptra_top_tb_axi_complex.sv`,
plus the JTAG DPI bundle (`jtagdpi.vpi`, built natively in
`evidence/caliptra-jtagdpi-native-20260923`). `[repo]`

Nothing needs to be recreated here. The blockers are compiler/runtime:
46 strict §6.5/§10.3.2 driver overlaps across two `axi_if` instances, 17,863
SVA-checker diagnostics in the unsafe lane, and time-zero reset ordering
(`BLOCKERS.md`, "CALIPTRA-*"; `evidence/caliptra-interface-driver-reducer-20260923`).
**This plan does not touch Track A.** The one external piece in this lane is
the licensed ARM `Axi4PC.sv`, whose placeholder is intentionally invalid at
`Axi4PC.sv:17` and is excluded by a filelist-only edit
(`evidence/caliptra-l0-icarus-baseline-20260923`). That is a Track B item
(§3.4).

### Track B — Official DV: UVMF unit/block and top environments

The pinned inventory counts 293 YAML test definitions (Caliptra 241, Adams
Bridge 52), 33 regression group lists, and 44 unit `.vf` entry points. The
official regressions need VCS plus inputs that are **absent**: UVMF 2022.3,
Questa QVIP 2021.2.1, Avery AXI VIP 2025.1, licensed ARM Axi4PC.
`[repo: evidence/caliptra-l0-52-and-full-dv-gap-20260923/README.md]`

Recorded unit census (44 entries, compile-only, not a runtime result)
`[repo: evidence/caliptra-icarus-dv-baseline-20260923]`: 20 compile pass, 6
fail, 17 setup (missing external input or include root), 1 unsupported (VVP
512-flag ceiling). Only 2 of 3 attempted unit runtimes pass.

**Track B is what this plan covers:** a clean-room, in-repo substitute for
the missing verification infrastructure, sufficient to run Caliptra's UVMF
environments **unmodified**, on Icarus, with meaningful traffic and checking.

### Why the evidence is thin

The same session logs say "UVMF, ARM AXI checker, and Avery inputs still
prevent a full Caliptra DV runtime claim" without ever recording *which UVMF
classes, which VIP sequences and which macros the pinned environments use*.
That inventory is the first deliverable (Phase 0). Without it, the surface
below is a guess.

---

## 2. Ground rules specific to this program

1. **Clean room, license first.** Do not copy Siemens/Mentor UVMF, QVIP or
   Avery source or encrypted models. Phase 0 must first determine whether UVMF
   is redistributable under its own license. If it is, vendoring the real
   library (as a pinned, hash-recorded input) beats recreating it and
   collapses Phase 2. QVIP and Avery are not assumed redistributable.
2. **Specified from use, not from memory.** The substitute implements exactly
   the API consumed by the pinned Caliptra/Adams Bridge sources, as measured by
   the Phase 0 manifest. Unused API is not built.
3. **A BFM that does nothing is not a BFM.** Per the AGENTS semantic-degradation
   rules: no always-ready slave that never checks, no monitor that never
   publishes, no scoreboard that never compares, no protocol checker that is an
   empty module. The Axi4PC substitute must either perform real checking or be
   left unbound and reported as an unsupported checker. It must not turn a
   missing licensed checker into a silent pass.
4. **The BFMs are themselves qualified artifacts.** A recreated VIP is a
   source of false passes and false failures. It needs its own negative
   controls (inject a protocol violation; the monitor/checker must flag it)
   before its results count as DUT evidence.
5. **Pinned Caliptra stays pristine.** Substitutes live in this repository and
   are supplied through filelists, `+incdir`, and environment-variable provider
   mappings (`UVMF_HOME`, `CALIPTRA_AXI4PC_DIR`, and the VIP equivalents found in
   Phase 0). Any unavoidable source change is a named, hash-guarded overlay in
   `release_overlays/`, recorded separately from unmodified-source results.
6. **Compiler gaps are blockers, not part of this program.** When the
   substitute exposes an Icarus defect, record a blocker/discovery with a
   minimal reducer and select it through the normal protocol. Do not widen a
   BFM item to fix the compiler, and do not rewrite the BFM to dodge the
   defect when the original construct is legal. A workaround in the substitute
   is allowed only when the original VIP's API is not what is being exercised,
   and it is labeled as such.
7. **Edition and mode honesty.** Report 2017 and 2023 separately. Name the
   generation mode that `.github/uvm_test.sh` used. A result in the
   "Icarus + recreated BFM" lane is not a VCS/Questa qualification and must not
   be reported as one.
8. **Results use the AGENTS UVM evidence ladder**: compiles, mechanisms
   execute, regression passes, real DPI, complex env compiles, meaningful
   traffic and checking, drains and terminates. Report the highest level
   actually reached per environment.

---

## 3. Target architecture

Layered so each layer is testable before the next depends on it.

```
L4  Caliptra / Adams Bridge UVMF environments   (pinned, unmodified)
L3  Protocol agents (QVIP / Avery replacements) (this program)
L2  UVMF base library: uvmf_base_pkg + util     (this program, or vendored)
L1  UVM (uvm-core, pinned; 2017 and 2023 modes) (existing)
L0  Icarus language/runtime                     (existing; gaps -> blockers)
```

### 3.1 L2 — UVMF base library

UVMF-generated environments split into an HVL (class) side and an HDL
(interface/module) side joined by proxy handles. The substitute must reproduce
the *observable contract* of the following, **subject to Phase 0 confirmation
of which are used** `[unverified]`:

| Area | Contents to confirm |
| --- | --- |
| Base classes | transaction, sequence, driver, monitor, parameterized agent, environment, test, virtual-sequence, predictor, scoreboard bases |
| Scoreboards | in-order, in-order race-free, out-of-order comparators with their mismatch/leftover reporting |
| HDL/HVL bridge | driver/monitor BFM interfaces with a `proxy` class handle, config-DB registration of virtual BFM interfaces, `initiate_and_get_response` / `wait_for_*` task protocol |
| Config/params | agent configuration objects, `*_parameters_pkg`, `*_typedefs` |
| Macros/utilities | the `uvmf_*` macros and util package |
| Register layer | any reg-adapter/predictor glue the environments instantiate |
| Top scaffolding | `hdl_top` / `hvl_top` / `*_test_base` startup order, clock/reset generation |

Deliverable is not "a package named `uvmf_base_pkg`". It is a package whose
behavior is pinned by tests derived from the consumer manifest (§5, Phase 2).

### 3.2 L3 — Protocol agents

Replace only the VIP endpoints the pinned environments instantiate. Candidate
set `[unverified]`: AHB-Lite, APB, AXI4/AXI4-Lite (the Track A internal
`axi_if` already shows USER and LOCK are exercised, with multi-beat mailbox
transfers `[repo]`), plus whatever Avery AXI is used for. Each agent provides:

- manager and subordinate roles, as the environments require;
- full-handshake, backpressure-capable driving, with configurable ready/valid
  behavior (including stalls), because always-ready hides bugs;
- bursts, IDs, response codes, USER sideband, exclusive/lock where the DUT uses
  them;
- a passive monitor publishing analysis transactions to the scoreboards;
- memory-model subordinate with defined behavior for unmapped/error accesses;
- inline protocol self-checks that raise real errors.

Ordering: follow the Phase 0 census; start with the protocol used by the
largest number of compile-passing units.

### 3.3 Reference prior art already in-tree

`/Users/danielellerbrock/projects/quick-and-dirty-eda/qd-bfm` (user's local
project, **not in this container**) has `qd_axi4_single_master.sv`, a
scalar-pin single-beat manager without AXI USER/LOCK or bursts
`[repo: evidence/caliptra-interface-driver-reducer-20260923]`. It is a possible
seed for the L3 AXI manager but falls short of Caliptra's needs; reuse requires
its license/ownership to be confirmed by the user.

### 3.4 Axi4PC (ARM protocol checker)

Treat as a distinct item. Options in order of preference: (a) leave unbound and
report "checker absent" (current behavior, honest); (b) implement a real AXI
protocol-check module covering the rules the SVA in Axi4PC actually asserts
(requires the rule list, which needs the licensed file or the public AXI spec);
(c) never a no-op module. Option (b) must itself pass violation-injection
controls.

### 3.5 JTAG DPI

Done natively and loaded with `vvp -d <bundle>` `[repo]`. Out of scope.

---

## 4. Compiler-readiness preview (to be measured, not assumed)

UVMF/VIP code is idiom-heavy. These are the Icarus capabilities the substitute
will lean on. Each is a *question for Phase 1*, not a known gap. The repo
already records evidence for some (virtual interfaces, modports, clocking,
parameterized classes, `bind` — see the 2017 clause matrix rows 8, 14, 25).

| Idiom | Question |
| --- | --- |
| Interface BFM holding a class `proxy` handle; interface tasks calling class methods and vice versa | Works across edition modes, with `-g2017` and `-g2023`? |
| `uvm_config_db#(virtual X_bfm)` set from `hdl_top`, get in `hvl_top` | Parameterized/typedef'd virtual interfaces, exact-type matching |
| Parameterized interfaces and agents with type parameters | Identity and modport-qualified VIF compare (matrix notes parameter-specialized VIF identity as open) |
| Interface task with `output`/`ref` args consumed from a class | Calling convention across `wait`/clock events |
| Clocking-block driving from interface tasks | Skew and region semantics (§14, §16.14) |
| Same-member continuous + procedural writes within a BFM interface | The exact §6.5 trap that blocks Track A today; the substitute must be legal under it |
| `bind` of checkers/SVA to BFM interfaces | Existing `bind` subset |
| Wide packed structs and dynamic arrays for burst data | Known strengths per census |
| Compile scale (VVP 512-flag ceiling hit by one unit) | Image size of full env |

---

## 5. Phases and exit gates

Each phase ends in a recorded, revision-scoped evidence directory. A phase is
not complete on "it compiled".

### Phase 0 — Consumer inventory and licensing (read-only)

Requires the pinned Caliptra + Adams Bridge checkouts (the standing single
Caliptra clone). **Blocked in this container; resume where the checkout lives.**

Deliverables (scripted and re-runnable, hash-recorded):
- License determination for UVMF, QVIP, Avery, Axi4PC; redistribution decision.
- `consumer_manifest.json`: for every UVMF-dependent test/env, the set of
  external packages imported, classes extended, methods called (with arity and
  override points), macros used, plusargs and `+define`s, filelist provider
  variables, and DPI imports. Counts per symbol; which of the 44 units and
  which UVMF top/block envs need each.
- Required-versus-present matrix over the 293 tests / 44 units / 33 groups.
- Decision record: vendor vs. recreate for UVMF; protocol set and order for L3.

Gate: manifest regenerates byte-identically; every `[unverified]` row in §3
is resolved to confirmed, refuted, or unused.

### Phase 1 — Idiom reducers (compiler readiness)

Minimal reducers (one per §4 row) in strict 2017 and 2023, with Slang as
differential evidence. Each failure becomes a `BLOCKERS.md` / DISCOVERED_DEBT
entry with the failing reproducer. No implementation here.

Gate: every idiom the manifest says is *used* is either PASS in both editions
or has a recorded blocker.

### Phase 2 — UVMF base library

Build only the manifest-selected surface (or vendor if licensing allows).
Pin behavior with unit tests of the library itself under the real-DPI UVM
driver:
- scoreboard in-order/out-of-order: match, mismatch, extra expected, extra
  actual, leftover at end — each must report the right count and severity;
- proxy/BFM startup order and config-DB handoff, including late registration;
- factory/override behavior of generated-style components.

Gate: tests pass in both editions; each has a negative control that fails when
the behavior is broken; a UVMF-style reference environment (toy DUT,
self-authored in generated style) runs end to end with nonzero traffic and a
scoreboard that is demonstrably able to fail.

### Phase 3 — Protocol agents (one protocol per sub-phase)

For each protocol: agent + monitor + subordinate memory model + self-checks.
- Cross-check against the in-tree Caliptra RTL (`ahb_lite_bus`, AXI fabric,
  `axi_if` tasks) used as an independent counterparty.
- Violation injection: dropped valid, early ready, wrong burst length, ID
  reordering, out-of-range address — monitor/checker must report each.
- Backpressure and stall sweeps; reset-in-the-middle recovery.
- Report agent's own functional coverage with denominators (not only 100%).

Gate: all injection controls detected; no false positives on the in-tree
counterparty; both editions.

### Phase 4 — Unit-level Caliptra/Adams Bridge UVMF environments

Order by the Phase 0 census: units already at "compile pass" first, then the
"setup" units that need only provider mapping (several fail solely on missing
`MLDSA_MEM_ADDR_WIDTH` / include roots — those are parameter/filelist setup
items `[repo]`, not BFM items, and must be classified as such rather than
credited to the BFM).

Per environment, required evidence (AGENTS UVM ladder):
- nonzero intended traffic and request/response activity;
- scoreboard compares performed, count recorded;
- zero unexpected UVM_ERROR/UVM_FATAL;
- no unexplained outstanding objections/transactions;
- normal termination.
A run with zero traffic or an unchecked scoreboard is recorded as failed.

### Phase 5 — Top-level UVMF environments and tests

Only after Phase 4 is stable across a meaningful set. Reconcile with Track A
(shared `axi_if`/mailbox concerns) without letting one lane's results stand in
for the other.

### Phase 6 — Qualification of the substitute

- Mutation controls over the BFMs and base library (flip a compare, drop a
  response, swap beat order) — each mutant must be caught by at least one test.
- Fingerprints recorded: compiler/runtime hashes, UVM generation mode, corpus
  revisions, seeds, commands, provider mappings.
- Published claim is capped at: "Icarus + recreated BFM, unmodified pinned
  sources, N of M environments at ladder level X, editions Y". Nothing in
  this program qualifies VCS/Questa behavior or IEEE 1800.2 conformance.

---

## 6. Proposed layout

```
dv/caliptra_vip/                 # new; not under uvm-core or Caliptra
  uvmf_lite/   (or third_party/uvmf if vendoring is permitted)
  agents/{ahb_lite,apb,axi4}/
  checkers/axi4_protocol_checker/
  providers/   env-var mapping + filelists consumed with -f
  tests/       library self-tests, negative controls, injection controls
docs/conformance/release_overlays/caliptra/   # only for unavoidable source overlays
evidence/caliptra-bfm-<phase>-<date>/         # revision-scoped, hash-recorded
```

Final layout and naming is a Phase 0 decision.

---

## 7. Proposed work items (not selected)

| Proposed ID | Phase | Depends on | Notes |
| --- | --- | --- | --- |
| CALIPTRA-BFM-INVENTORY | 0 | pinned checkouts | Read-only; first and mandatory |
| CALIPTRA-BFM-LICENSE-DECISION | 0 | inventory | Vendor vs recreate gate |
| CALIPTRA-BFM-IDIOM-REDUCERS | 1 | inventory | Reducers only |
| UVMF-LITE-CORE | 2 | decision, idiom results | Base classes + bridge |
| UVMF-LITE-SCOREBOARDS | 2 | CORE | With negative controls |
| UVMF-LITE-REFERENCE-ENV | 2 | CORE, SCOREBOARDS | Toy DUT, end-to-end gate |
| CALIPTRA-VIP-<PROTOCOL> | 3 | REFERENCE-ENV | One per protocol, census order |
| CALIPTRA-AXI4PC-DECISION | 3 | inventory | Unbound-and-report vs real checker |
| CALIPTRA-UNIT-ENV-<NAME> | 4 | protocol agents | One per unit environment |
| CALIPTRA-BFM-MUTATION-QUAL | 6 | all above | Gate for any published claim |

Per AGENTS, "Unrelated discoveries" found along the way go to
`DISCOVERED_DEBT.md`, and compiler work found by Phase 1 or later goes
through its own blocker, not this list.

---

## 8. Risks

- **Inventory may show the surface is large.** Full QVIP is thousands of
  lines; only the consumed subset is built, but a heavily used subset can
  still be large. Phase 0 sizes this before commitment.
- **Behavioral fidelity.** Hidden VIP defaults (response latency, error
  injection defaults, memory fill value) can change test outcomes. Where the
  environment depends on a default, the manifest must record it; unknown
  defaults are listed as assumptions, never silently picked.
- **Compiler blast radius.** Phase 1 may surface blockers in virtual-interface
  identity, interface-task/class interplay, or scale limits. These compete with
  the OpenTitan queue for the one-active-blocker slot.
- **False confidence.** A passing environment on a permissive BFM proves little.
  Phase 6 mutation controls exist to counter this and are not optional.
- **Wall-clock.** The census shows full-top runs are slow (Adams Bridge adders
  dominate: `session_logs/2026-09-28_caliptra_singlecore_compiler_assessment.md`).
  Unit-level environments are the realistic first target; top-level is
  deferred.

## 9. Open questions for the owner

1. Where does the pinned Caliptra/Adams Bridge checkout live now? Phase 0
   cannot start in this container without it.
2. Is a licensed UVMF 2022.3 copy available locally for *reading* (not
   redistribution), and does its license permit vendoring?
3. Is `qd-bfm` yours to relicense/reuse as the AXI manager seed?
4. Priority: unit-level UVMF environments first (recommended) or top-level
   tests first?
5. Is a real Axi4PC substitute wanted, or is "unbound, reported absent"
   acceptable for the first qualification claim?
