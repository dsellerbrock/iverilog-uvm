# §§23.8, 23.8.1, and 23.9 name-resolution probes

Raw results are recorded; the 1800-audit lead has not classified this tranche. No conformance claim or issue count is assigned here.

## Environment

- Host: DAN-DESKTOP Slurm, pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb` (Icarus 13.0 devel).
- Jobs 3780 and 3781 completed with scheduler `ExitCode=0:0`; each requested 1 CPU and 1 GiB. Every compile/run process had a 30-second timeout. Slurm runtime rounds to 0 seconds; accounting is disabled, so peak RSS is unavailable.
- The harness ran each case under `-g2017` and `-g2023`, using `iverilog -g<edition> -B <toolchain>/lib/ivl` and `vvp`.
- Job 3780 initially wrapped the standard hierarchy in a convenience `top` module. Its R1 result matched, but job 3781 reran R1 with the standard's two root modules and no wrapper; that exact-root result also matched.

## Results

| Probe | Requirement checked | `-g2017` | `-g2023` |
| --- | --- | --- | --- |
| R1 exact-root `a/b/c/d` hierarchy | §23.8 upward hierarchical references | Compile/run pass; `1 2 2 4 5 6 2 8` | Same |
| R2 upward reference assignment | §23.8 upward reference observes updated ancestor variable | Compile/run pass; `7 7` | Same |
| R3 `$unit` task calls a later-declared function | §23.8.1 compilation-unit subroutine lookup | Compile/run pass; `2` | Same |
| R4 generate-local function shadows wildcard-imported package function | §23.8.1 enclosing-scope lookup precedes wildcard import | Compile/run pass; `top.b.f` | Same |
| N1 uninstantiated `if (0) begin : g` collides with module variable `g` | §23.9 one declaration per scope; §27.5 generate naming nuance | Correctly rejected, rc 1: `'g' has already been declared in this scope` | Same |

The §27.5 check matters for N1: the conditional generate branch is unselected, but its named block still conflicts with a declaration in that scope. No run result applies to this negative compile case.

## Issue search and references

A fresh open-and-closed GitHub snapshot contained 436 issues (309 open, 127 closed). Exact assigned search terms had no direct hits. Expanded searches found only distinct neighbors: closed #19 is a broad `$unit` tracker without the §23.8.1 forward-function requirement; #817 covers a package-reference rule; #926 covers `$printtimescale`; #928/#930 cover separate §23.10 `defparam` rules. Full terms and hits are in [DEDUPE.md](DEDUPE.md), with the full issue snapshot in `dedupe-all-issues.json`.

The 2017 text was checked at pp. 727–730 and the 2023 text at pp. 759–761. The tested requirements are §§23.8, 23.8.1, and 23.9; the negative naming nuance is §27.5.

## Evidence files

- Job 3780 raw logs/results and scheduler record: [raw-slurm-3780](raw-slurm-3780/).
- Exact-root follow-up job 3781 raw logs/results and scheduler record: [r1-root-followup/raw-slurm-3781](r1-root-followup/raw-slurm-3781/).
- Probe sources, manifests, and launch commands: [job 3780 input](input/), [R1 exact-root source](r1-root-followup/input/R1_upward_standard_abcd.sv), [run.sh](run.sh), [run.sbatch](run.sbatch), and [tool versions](r1-root-followup/tool-version.txt).
- 3781 source SHA-256: `af3e31233088048d6d85e1444bef8decf51fead854ce7f18b746da3068e2dcdd`; the local staged source hash matches the remote copy.
- After copying evidence, removed only job 3781's staged inputs, VVP work directory, manifest, and run scripts; its remote directory shrank by 11,812 bytes. Logs and results remain.

The audit lead call was attempted after the user's quota-reset note, but the helper returned `daily lead cap reached (40)`; this differs from the reported 160-call allowance. The probes and dedupe are preserved for lead classification. No issue was filed by A3.
