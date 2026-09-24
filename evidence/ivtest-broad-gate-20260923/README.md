# Eight legacy ivtest gate failures, 2026-09-23

The full JSON VVP regression also passed on `8c88d069c`: 3,388 run,
zero failed, exit 0. Its exact result and compressed raw output are in
`merged-json-result.json` and `merged-json.log.gz`.

Source HEAD at triage: `6e1af2425869f078e91689a2e3972e45429451e5`.
Installed compiler SHA-256: `1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`.
Installed VVP SHA-256: `f2a05ce45cdb2271af25dee78f62203926a34844cd202192e5af4c69ab3829ab`.
The full gate's failure names came from
`/tmp/ivl-focus-20260923/ivtest-gate-current.log`.
`failure_comparison.json` preserves the exact legacy actual and gold text for
each name. No compiler source or shared runner output was changed here.

| Legacy failure | Finding | Test-only repair |
| --- | --- | --- |
| `pr1787423b` | Its initial block checked primitive outputs before time-zero Active propagation and saw `zz`; `pr1787423b_std` already waited `#1` and passed. IEEE 1800-2017/2023 §§4.5, 4.9.1 place initialization and continuous-assignment evaluation in the time-zero slot, without guaranteeing this immediate Active observation. | Insert one `#0` before the existing checks; all checks remain at time zero, now in Inactive after Active settles. The isolated copy `pr1787423b_after_active.sv` passed. |
| `sv_constraint_dist_boolean_subject`; `sv_dist_large_exact_nonsingleton_expression_fail` in 2017 and 2023 | Behavioral checks printed `PASSED`; failure was solely exact diagnostic wording after the solver's broader bounded coupled-range implementation. | Update both legacy and JSON stderr gold text. |
| `sv_randomize_joint_multiple_dist_fail` in 2017 and 2023 | A 301-coordinate range now returns success with valid constrained values, so its old 256-coordinate cap assertion fired. | Test a 20,001-coordinate range on a 15-bit subject and child for negative transactional rollback; add an independent 301-coordinate positive control. |
| `sv_randomize_joint_ordered_randc_multidist_range_cap_atomic` in 2017 and 2023 | The same former 301-coordinate cap case now solves with a valid ordered assignment and one post-randomize callback. | Test the 20,001-coordinate negative with original value/RNG/randc rollback and replay assertions; add a separate 301-coordinate positive control. |

The paired direct probes and original-versus-`#0` primitive control are in
`focused_probe_results.json`. They use only isolated `/tmp/ivl-broad-gate-agent-20260923`
outputs. Its original primitive case emitted two `zz` failures, while the
existing `#1` sibling and `#0` copy each printed `PASSED`. Both editions
returned `randomize()=1` on the former 301-coordinate cases with valid values.

Focused regression runners used the unchanged installed binaries through
`PATH=<worktree>/local-install/bin:$PATH`, from the isolated scratch ivtest
directory, with symlinks to the current source/gold trees:

```text
perl <worktree>/ivtest/vvp_reg.pl focus-legacy.list
python3 <worktree>/ivtest/vvp_reg.py focus-json.list
```

`focus-legacy.log` records 8/8 passed and `focus-json.log` records 7/7 passed.
Their exact list files are preserved here. `git diff --check` passed for the
edited test source and gold files. The coordinator's subsequent merged-branch
full gate passed; `merged-gate-result.json` records its exact revision and
counts. The first failing and merged passing gate summaries are preserved as
`first-fail.log.gz` and `merged-pass.log.gz`.
`uvm-real-dpi-result.json` and its compressed log record the separate passing
real-DPI UVM run on the pre-merge candidate binaries. It was not rerun after
the independent `origin/main` array-parameter change; exact-head CI remains
the final combined UVM check.
