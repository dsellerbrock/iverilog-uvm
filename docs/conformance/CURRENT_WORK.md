# CURRENT WORK — continuation state

**What this file is.** The shortest thing a new session can read to know
where work stands and what to pick up. It is a pointer, not a log.

- **What is left, and in what order** → `ROADMAP.md`. That is the single
  living tracker; this file never duplicates its rows.
- **Policy and architecture** → `iverilog_ieee1800_uvm_manifesto.md`.
- **Per-checkpoint history** → `session_logs/`. Everything this file used
  to carry inline (2026-07-14 .. 2026-07-21, ~110 KB) is archived verbatim
  in `session_logs/2026-07-14_to_2026-07-21_current_work_archive.md`.

**Rule:** when a campaign closes, its narrative goes to a dated
`session_logs/` entry and this file keeps only the resume state below.

---

## Resume state — 2026-07-25 (Campaign 1: M6/M7 scheduler and UVM)

**Branch:** `claude/ieee1800-closure-campaign-lqalye`.

**Closed in this campaign so far:**

- **Issue #98** — the UVM phase-hopper objection reaching `uvm_root`. The
  language-level defect behind it was fixed by the #103 work (a nested
  detached fork's implicit `this` resolving to null); this campaign
  supplied the missing half of the acceptance boundary:
  `m7_post_run_phases_test` proves extract/check/report/final all execute,
  in order, after a run_phase held open by two-level concurrent objection
  traffic, with the run still ending at t=80.
- **R2 / M6B-4** — assertion ACTION blocks now run in the **Reactive**
  region (4.4.2.5), one region after the Observed evaluation. The earlier
  attempt at this was reverted for dropping end-of-simulation verdicts;
  both causes were runtime defects and are fixed: `%wait/reactive` runs
  inline wherever no Reactive region is reachable (final blocks,
  Postponed, post-simulation), and a thread resumed by a region deferral
  is exempt from the `of_VPI_CALL` freeze that `$finish` otherwise applies
  mid-body.
- **M6B-2** — `cbNBASynch` (reason code 30) defined, registered and backed
  by a real `SEQ_NBASYNC` queue drained after NBA and before Observed.
- **M6B-3** — time-consuming DPI imports pinned as schedulable processes
  (`join_any` returns while one is parked; `disable fork` abandons it for
  good).

**Preempted into (rule gate 1 — silent wrong results jump the queue):**

- **M3B-8** inherited constraints were solved class by class, so a
  base-only re-solve overwrote the full solution and silently violated a
  derived hard constraint. Now one solve over the complete set.
- **M3B-9** soft-constraint priority (18.5.14.1) was settled by weight
  sum rather than declaration order. Each `soft` is now its own
  lexicographic objective, and the compiler emits inherited constraint
  lists in ascending declaration order so list position is priority.
- **M4B-11** `'{default: value}` was rejected everywhere (parsed as a
  one-element positional pattern) and the `'{N{...}}` replication count
  was dropped by every elaboration path — silently wrong on a packed
  target.

**Campaign 1 is closed.** M6B is COMPLETE (all four items), M7 is
verified at 224/0/0 with an empty known-fail list, and the region
pipeline self-test drains Preponed → Active → NBA → NBASync → Observed →
Reactive → Re-NBA → RWSync → ROSync in order under reverse insertion.

**M1C-1 is fixed.** The ICE — `foreach` over a runtime-sized array inside
a `$unit`-scope class constructor — was a named block scope being
elaborated twice: `PBlock::elaborate_scope` built a second `NetScope` for
the same name under the same parent, orphaning the one the signature pass
had declared the loop variable into. A same-named child of the same
parent is now reused. Pinned by `sv_foreach_in_class_constructor`;
`repros/foreach_in_unit_class_constructor_ice.sv` keeps the minimization
trail.

**M1C-3 is fixed** — the largest thing this campaign has turned up. An
element of a container held in a CLASS PROPERTY was being addressed with
the property-SLOT index, and the slot holds the container, not the
element. Three silent defects fell out of that one shape: null guards
read non-null for null elements (so lazy allocation silently skipped),
member writes through an element hit the container (abort for index ≥ 1),
and whole-element stores of an unpacked struct aliased the source so
every element ended up holding the last value. Pinned by
`sv_class_property_container_element`.

**Where to look first when resuming:** the `Current focus` list at the
bottom of `ROADMAP.md`. It is re-derived from the priority rule, not
hand-picked.
