# Cost-aware hierarchical regression policy

Principle: run the smallest suite capable of detecting the likely failure of
the current change; escalate by risk. Optimize the PLACEMENT of expensive
validation, not its existence. Full UVM is a checkpoint/promotion gate, not
an inner-loop tool.

## Measured suite costs (this container, 2026-07-23)

| Suite | Cost | Command |
|---|---|---|
| Tier 0: single test (compile+run) | ~2-6 s | `iverilog -g2012 ... && vvp ...` |
| Tier 0: single UVM test | ~8-12 s | `.github/regression/run_uvm_subset.sh <name>` |
| Tier 1: negative suite (53) | ~40 s | `tests/negative/run_negative.sh` |
| Tier 1: sva_nfa dual-run (33) | ~40 s | `tests/sva_nfa/run.sh` |
| Tier 1: full ivtest SV list (~1045) | ~3-4 min | `cd ivtest && perl vvp_reg.pl regress-sv.list` |
| Tier 2: targeted UVM group | ~1-8 min | `run_uvm_subset.sh --group <group>` |
| Tier 3: UVM smoke (14) | ~2-3 min | `run_uvm_subset.sh .github/regression/smoke.list` |
| Tier 4: full UVM (212) | ~25-30 min | 4 batches via `UVM_TESTS_DIR` (never in parallel: `/tmp/uvm_dpi_iv.vpi` race) |
| Tier 5: full project | Tier 4 + Tier 1 + CI 6-platform | promotion gate |

## Tiers

- **Tier 0 — microtests**: exact reproducer + directly adjacent positive/
  negative/adversarial tests. Run after almost every meaningful edit.
- **Tier 1 — focused subsystem**: negative + sva_nfa (always cheap enough) +
  full ivtest at coherent increments. ivtest is cheap here (~3.5 min) and
  broad — treat it as the default increment gate.
- **Tier 2 — targeted UVM**: `.github/regression/groups.conf` maps subsystems
  to test globs; `.github/regression/fingerprints.conf` maps changed source
  files to groups. Run the mapped groups.
- **Tier 3 — UVM smoke**: `.github/regression/smoke.list` (14 cross-cutting
  tests: boot/factory, config DB, vif+cfgdb, objections, sequences, TLM,
  callbacks, field automation, RAL basic + front door, type-param stress,
  scheduler litmus, DPI). Run before promoting a normal feature commit and
  after shared elaborator/runtime changes.
- **Tier 4 — full UVM**: mandatory before milestone COMPLETE, major PR merge,
  scheduler/class-representation/call-frame/container-runtime architecture
  changes, UVM package changes, or when adversarial testing reveals
  unexpected blast radius. Periodic: HIGH-risk commits since last full >= 2,
  or stable commits since last full >= 8 (tracked in
  `.github/regression/UVM_DEBT.md`). Never rerun on an identical
  already-passed commit.
- **Tier 5 — full project**: Tier 4 + all Tier 1 + CI matrix. Promotion gate.

## Risk levels

- **LOW** (isolated diagnostic, docs, narrow unsupported-syntax handling):
  Tier 0 + relevant Tier 1.
- **MEDIUM** (local elaborator behavior, one container method, isolated SVA
  operator): Tier 0 + Tier 1 + mapped Tier 2 + optionally Tier 3.
- **HIGH** (vthread/scheduler, call frames, virtual dispatch, class object
  representation, shared expression typing, aggregate codegen, DPI ABI,
  broad grammar): Tier 0-3 always; Tier 4 before promotion.
- **CRITICAL** (semantic IR migration, scheduler queues, object memory
  representation, core VVP loop): all tiers before promotion.

The Implementation Engineer states the risk level before selecting gates.
The Adversarial Engineer may escalate it and must name the targeted UVM
tests most likely to expose the defect.

## Ordering & discipline

Fast-failure order: reproducer -> adjacent micro -> Tier 1 -> Tier 2 ->
smoke -> full. Stop escalation on the first failure; fix first. Do not run
UVM batches concurrently (shared `/tmp/uvm_dpi_iv.vpi`; historical
load-flake: m9h_combinator under parallel load). Cache: record full-UVM
passes per commit in UVM_DEBT.md; never rerun the same commit.

## Evidence-driven growth

When a broad run catches what a focused run missed: identify the small test
that would have caught it, add it to the right group in groups.conf, and
extend fingerprints.conf. CI: per-push runs Tier 1 + smoke-equivalent; the
6-platform matrix remains the merge gate (full suite).
