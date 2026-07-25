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

**Where to look first when resuming:** the `Current focus` list at the
bottom of `ROADMAP.md`. It is re-derived from the priority rule, not
hand-picked.
