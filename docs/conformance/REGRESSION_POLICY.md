# Cost-aware hierarchical regression policy

Principle: run the smallest suite capable of detecting the likely failure of
the current change; escalate by risk. Optimize the PLACEMENT of expensive
validation, not its existence. Full UVM is a checkpoint/promotion gate, not
an inner-loop tool.

## Commands and evidence

The [README](../../README.md#testing) owns full-suite commands. For narrower
UVM runs use `.github/regression/run_uvm_subset.sh <name>` or `--group <group>`
from the repository root. Suite membership lives in the runner and list files.
Costs vary by host and revision; old July timing estimates are not current budgets.

[CURRENT_WORK](CURRENT_WORK.md) links the latest committed qualification.
[CAMPAIGN](../../.ai/CAMPAIGN.yaml) records operational pending gates and the
last validated revision. The [July UVM ledger](../../.github/regression/UVM_DEBT.md)
is historical. Do not copy its counts into a current pass claim.

## Tiers

- **Tier 0 — microtests**: exact reproducer + directly adjacent positive/
  negative/adversarial tests. Run after almost every meaningful edit.
- **Tier 1 — focused subsystem**: negative + sva_nfa +
  full ivtest at coherent increments. Use the active ticket and
  [AGENTS](../../AGENTS.md) to select directly affected gates.
- **Tier 2 — targeted UVM**: `.github/regression/groups.conf` maps subsystems
  to test globs; `.github/regression/fingerprints.conf` maps changed source
  files to groups. Run the mapped groups.
- **Tier 3 — UVM smoke**: `.github/regression/smoke.list` (cross-cutting
  tests: boot/factory, config DB, vif+cfgdb, objections, sequences, TLM,
  callbacks, field automation, RAL basic + front door, type-param stress,
  scheduler litmus, DPI). Run before promoting a normal feature commit and
  after shared elaborator/runtime changes.
- **Tier 4 — full UVM**: mandatory before milestone COMPLETE, major PR merge,
  scheduler/class-representation/call-frame/container-runtime architecture
  changes, UVM package changes, or when adversarial testing reveals
  unexpected blast radius. Periodic: HIGH-risk commits since last full >= 2,
  or stable commits since last full >= 8 (tracked in
  the campaign handoff against its last validated revision). Never rerun on an identical
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
passes with exact tool/input fingerprints in the qualification record;
[CURRENT_WORK](CURRENT_WORK.md) links it. Reuse identical validated evidence;
changed tools, inputs, or unresolved concerns require fresh checks.

## Evidence-driven growth

When a broad run catches what a focused run missed: identify the small test
that would have caught it, add it to the right group in groups.conf, and
extend fingerprints.conf. CI requirements live in
[the workflow](../../.github/workflows/test.yml); required remote checks remain
merge gates.
