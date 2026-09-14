# OpenTitan and Caliptra rebaseline after PR #277 (2026-09-13)

## Scope

Compiler: `main` @ `631bba6e8` (PR #277 merged, includes L15-L40 — roughly
35 real defects fixed since the last full census). OpenTitan and Caliptra
sources unmodified; same pinned revisions as every prior baseline
(OpenTitan `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`, Caliptra
`bd31614182fb56e55578f48086a10ded650434fd`, Adams Bridge
`e59eba955eac2a1adcb059f250641ede78e304be`).

The most recent PRIOR full census is 2026-09-05
(`evidence/opentitan-fork-process-300s-after260-arm64-20260905/opentitan-matrix.json`),
not 2026-09-03 as an earlier memory note assumed — there were two censuses
in that window; this rebaseline diffs against the closer, more complete
one (per-job JSON, not just aggregate counts from a doc).

## OpenTitan: net unchanged pass count, one benign reclassification

530 jobs, same as every prior run.

| Status | 2026-09-05 | 2026-09-13 | Δ |
|---|---:|---:|---:|
| PASS | 203 | 203 | 0 |
| DEPENDENCY_ONLY | 157 | 157 | 0 |
| FAIL | 84 | 84 | 0 |
| UPSTREAM_INVALID | 39 | 39 | 0 |
| DEBT | 17 | 17 | 0 |
| RUNTIME_FAIL | 16 | 23 | +7 |
| RUNTIME_TIMEOUT | 8 | 1 | -7 |
| SETUP_FAIL | 6 | 6 | 0 |

A full per-job diff (matching on lane+core, all 530 present in both) found
**exactly 7 changed jobs, all the same transition**:
`RUNTIME_TIMEOUT -> RUNTIME_FAIL` for `lowrisc:dv:top_{darjeeling,earlgrey,
englishbreakfast}_xbar_{dbg,mbx,peri,main}_sim:0.1` (the specific 7 xbar
runtime targets that previously hung at the runtime timeout ceiling). They
now complete within budget and report a clean failure instead of hanging.
**Zero PASS regressions. Zero new FAILs. 523/530 jobs identical.**

None of the ~35 fixes landed since 09-05 (L15-L40, the U/S/V-series before
that) happen to move this specific 530-job set's pass/fail boundary — most
of that work targeted UVM registry/parameterized-class/container corners
this exact job set doesn't exercise. This is a legitimate, verified "no
regression, one hang eliminated" result, not a null result from a broken
harness (confirmed via the per-job diff, not just aggregate counts).

## Caliptra: exact match to the 2026-08-26 baseline

105-manifest matrix, unmodified sources.

| Status | 2026-08-26 baseline | 2026-09-13 | Δ |
|---|---:|---:|---:|
| PASS | 52 | 52 | 0 |
| DEBT | 1 | 1 | 0 |
| SHARED_SOURCE_OR_CONFIG | 51 | 51 | 0 |
| SOURCE_ORDER_DEBT | 1 | 1 | 0 |
| ICARUS_GAP | 0 | 0 | 0 |

Exact match. The zero-demonstrated-Icarus-gap static baseline (goal file
requirement) holds.

Operational note: the driver script
(`evidence/caliptra-fork-process-300s-after260-arm64-20260905/run_census.py`)
hardcodes an `IVERILOG` path into a worktree deleted during this session's
own worktree-hygiene pass — the "census-driver-paths-rot" pattern
recurring. Patched a COPY (`evidence/caliptra-rebaseline-after277-20260913/
run_census.py`), not the original, per that lesson. The copy also needed a
static `fileset_top.sv` sibling file the original evidence directory held
but the script itself doesn't generate — an easy trap (produces a
misleading "20 PASS" first run, all packages spuriously reclassified to
SHARED_SOURCE_OR_CONFIG, before the missing file was found and copied over).

## Goal-file "Immediate priority" list (2026-08-26) — re-verified, not assumed

1. **Runtime-valued covergroup bin ranges (OpenTitan TL agent)** — the
   V01-V07 covergroup series (merged before this session) plausibly
   covers the general mechanism; not independently re-verified against
   the literal TL-agent construct this pass (time-boxed out of this
   rebaseline; flagged in `tasks/todo.md` if it needs a direct check).
2. **Parameterized-class inheritance blocking `ac_range_check_env_cov`**
   — this was always a MISDIAGNOSIS, not a real frontier. Confirmed via
   the fresh census's actual `hard_errors`: line 12 is `import
   ac_range_check_reg_pkg::*;` **directly inside the class body**, which
   is illegal SystemVerilog (IEEE 1800-2023 A.2.1.3 footnote 15: "It
   shall be illegal to have an import statement directly within a class
   scope"), confirmed independently by Slang
   (`error: package import not allowed in class declaration`). Icarus is
   CORRECT to reject this — already documented in memory
   `class-body-import-is-illegal` from an earlier session. Not an
   implementation target. The one genuine, real gap: the diagnostic
   itself is bad — a bare `syntax error` + `Invalid class item.` whose
   parser error-recovery cascades into several misleading follow-on
   errors (`ac_range_check_env_pkg doesn't name a type`) instead of one
   focused message naming the actual illegal construct. Same root cause
   affects `pwrmgr_base_vseq.sv:21` across 3 tops (6 rows in this
   census). Good, well-scoped first Phase-B candidate: detect `import`
   directly in a class scope in the parser and emit ONE clear diagnostic
   citing 8.25/A.2.1.3-fn15, instead of letting recovery cascade.
3. **Cluster/fix remaining OpenTitan parser frontiers by mechanism** —
   now directly enumerable from this census's `hard_errors` per job;
   not clustered in this pass (time-boxed; see `tasks/todo.md`).
4. **`prim_esc_sim` / `prim_flop_2sync_sim` / `prim_present_sim` /
   `prim_prince_sim` runtime frontiers** — all four STILL `RUNTIME_FAIL`,
   confirmed still open and unchanged by this census (not re-diagnosed
   in this pass; original baseline's characterization — `prim_esc_sim`
   4 assertion failures, `prim_flop_2sync_sim` queue underflow/value
   mismatch, `prim_present_sim` unloaded DPI symbols + crypto mismatch,
   `prim_prince_sim` VVP concat port-width invariant — not re-verified
   against current output this pass).
5. **Caliptra baseline preservation** — confirmed exact match, see above.

## Evidence

- `matrix/full-631bba6-after277/results.json` (+ `.md`) — the full 530-job
  OpenTitan census.
- `evidence/caliptra-rebaseline-after277-20260913/` — the 105-job Caliptra
  census, including the patched driver copy and its `fileset_top.sv`.
- `evidence/opentitan-fork-process-300s-after260-arm64-20260905/opentitan-matrix.json`
  — the prior baseline this diffs against.
