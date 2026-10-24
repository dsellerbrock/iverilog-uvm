# §§23.8, 23.9, and 26.3 name-resolution boundary probes

The audit lead has not made final classifications. The raw results below are observations; `$unit::` forward-variable acceptance is a candidate gap pending one non-task control and lead dedupe/classification.

## Environment

- Pinned Icarus 13.0 devel, SHA `cc25756d187314742d347267c2a513b3e640a7fb`, on DAN-DESKTOP Slurm.
- Job 3782 completed with scheduler exit 0:0, 1 CPU/1 GiB; 13 cases paired under `-g2017` and `-g2023`, with a 30-second timeout per compile/run process. Raw results and logs are under [raw-slurm-3782](raw-slurm-3782/).
- Every positive control compiled and ran in both editions with its expected output: `1 1`, `9`, `2`, `7`, and `3`.
- Job 3783 reran the malformed type case with corrected source and added a non-task `$unit::` forward-reference case plus its declared-before-use control. It completed with scheduler exit 0:0; raw records are under [unit-forward-followup/raw-slurm-3783](unit-forward-followup/raw-slurm-3783/).
- The read-context generate check initially compiled with an unresolved-reference warning in job 3784. Job 3785 reran it and executed the resulting binary: the uninstantiated `if (0)` case prints `32`, while the instantiated `if (1)` control prints `7`, both editions. Raw records are under [genhier-read-followup/raw-slurm-3784](genhier-read-followup/raw-slurm-3784/) and [genhier-runtime-followup/raw-slurm-3785](genhier-runtime-followup/raw-slurm-3785/).

## Job 3782 observations

| Probe | `-g2017` | `-g2023` | Assessment pending lead |
| --- | --- | --- | --- |
| Unqualified `$unit` task reference to later `b` | rc 1; diagnostic says `Unable to bind ... b` and explicitly identifies declaration after use | Same | Rejection matches §23.8 |
| `$unit::b` in the same task, with `b` declared later | rc 0, no diagnostic; no simulation run | Same | Accepts an invalid forward reference under §23.8 |
| Type referenced before its compilation-unit typedef | Source was malformed by the staging shell command; compiler output is excluded | Same | Corrected isolated rerun is job 3783 |
| §26.3 wildcard import, use of `x`, then local declaration of `x` | rc 1; `x` already imported from package `p` | Same | Matches the standard's required conflict |
| Assignment through `top.g.v` in an `if (0)` block | rc 1; warning says variable could not be found, followed by `Elaboration failed` | Same | Assignment form is rejected, but only with a warning and generic elaboration failure |
| `if (1)` named block `g` colliding with module variable, either declaration order | rc 1; duplicate `g` diagnostic | Same | Rejection matches §§23.9/27.5 |
| Zero-trip `for` generate named `g` colliding with module variable `g` | rc 1; duplicate `g` diagnostic | Same | Rejection matches §§23.9/27.5 |

Job 3783's corrected type-forward case is rejected in both editions with `mytype doesn't name a type`; its declared-before-use type control prints `9`. The `$unit::b` module-initializer forward reference also compiles silently in both editions, while the declared-before-use module-initializer control compiles and runs. That control prints `1`: its source declares `bit b = 7`, so the one-bit value truncates to 1. The manifest's expected-output field mistakenly says 7; the runner records raw output and does not compare that field. This is an evidence annotation error, not a simulator mismatch.

The hierarchy read-form probe is more concerning than the assignment form: job 3784 compiles `top.g.v` with only `warning: Unable to bind ... (compile-progress: unresolved reference)`, rc 0. In job 3785, both editions also run successfully and print `32`; the matching instantiated-block control prints `7`. The compiler therefore accepts and executes an invalid reference to a block omitted by `if (0)`. This is a likely §23.9/§27.5 gap, but the audit lead must decide whether it is covered by closed #500, whose stated scope is unresolved hierarchical task calls on unindexed module/generate hierarchy, or needs a separate issue.

The malformed `N_unit_forward_type.sv` in job 3782 is preserved exactly in `input/` and matches `raw-staged-sha256.txt`; its rc 3 is not a standards result. Job 3783 is the valid type probe. The §26.3 source follows the standard example's scope structure. The assignment-form reference into an uninstantiated hierarchy exits nonzero but emits a warning; a read-context follow-up with an instantiated control is job 3784 and is pending.

## Standards and dedupe

- IEEE 1800-2017 §23.8 p. 54 explicitly distinguishes task/function forward references from other compilation-unit identifiers and says `$unit::` does not enable later declarations; the example's later `bit b` reference is illegal. 2023 wording matches for the tested rule.
- §23.8.1's forward task/function rule is tested by R3/R4 in [the preceding tranche](../attempt-06-name-resolution/RESULT.md).
- §23.9 covers one declaration per scope and whether a generate block is instantiated; conditional/loop naming is in §27.5.
- IEEE 1800-2017 §26.3 pp. 777–782 contains the wildcard-import/later-declaration example used here; the tested 2023 text matches.
- Fresh issue snapshot: 436 total (309 open, 127 closed). No direct `$unit::b`/forward-variable match. Closed #19 broadly lists `$unit::name` visibility but does not state this before-declaration rule; open #817 is the distinct §26.2 package-to-compilation-unit prohibition. For the hierarchy candidate, closed #500 is the only `generate hierarchy` hit; it covers missing hierarchical task calls, while the new probe is a variable reference. See [DEDUPE.md](DEDUPE.md) and [DEDUPE-hier-uninstantiated.md](DEDUPE-hier-uninstantiated.md).
- A separate technical-advice call judged the `$unit::b` acceptance an invalid acceptance under §23.8 and distinct from #19, while reserving final classification and filing to the audit lead. It also requested the module-initializer control in job 3783.

The required `--lead 1800-audit` call still returns `daily lead cap reached (40)` despite the user's note of a 160-call limit with 26 used. A3 has filed no issue; §23.8 remains lead-pending. Normal technical-advice calls say the `$unit::` acceptance violates §23.8, is distinct from #19, and merits a narrow candidate issue, but the audit lead must classify and file it.
