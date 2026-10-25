# #836 T1 selection

Graphify identifies `pexpr_to_constraint_ir()` in `elaborate.cc` (degree 147) and the constraint/dist test community, including `sv_constraint_dist_boolean_subject.v`. The impacted area is all active `dist` regression rows, not only tests with the new diagnostic.

- Legacy: 140 existing active-dist rows plus the four new paired #836 regressions (144 total).
- JSON/VVP: 147 existing active-dist rows plus the four new paired #836 regressions (151 total).
- Each JSON row runs individually under `scripts/run_with_timeout.py 300`, so a hang is killed per test. The legacy runner has per-test timeouts in `ivtest/vvp_reg.pl`.
- Prior baseline differential: 140/140 legacy and 147/147 JSON rows matched main before final classifier/test edits.
- Slurm job 4775 completed in 27:09 (peak RSS 1.60 GiB): 144/144 legacy, 151/151 JSON, and 367/367 UVM passed.
- Full legacy/JSON/UVM logs, summary, exit code, and timing are recorded under `evidence/m9-issue836-probe-20261024/t1-slurm-evidence-20261024/`.
