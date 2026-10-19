# #667 corrected T0/T1 qualification

Job 3112 uses the repository's expected `$SOURCE/local-install` prefix. It
builds the exact source archive, runs the exact class-property compile
reproducer plus the sample-formal 1024-bin/cross assertions in legacy and JSON
for 2017 and 2023, runs `ci/run-smoke.sh`, and selects all covergroup tests for
T1 from both runners. It also compiles the §19.5.3 non-power-of-two audit probe
under both editions; that probe is expected to fail on this partial-support
branch and is recorded separately from the T0/T1 gate.

T1 selection: every `sv_covergroup_*` case in `ivtest/regress-sv.list` and
`ivtest/regress-vvp.list`. The change touches covergroup elaboration in
`elaborate.cc` and sample-time bin matching in `vvp/vthread.cc`, so this
selection exercises both modified paths.

Final result: build and install passed (peak RSS 1,670,156 KiB); the issue
legacy runner passed 2/2. The JSON runner failed both entries only because the
new test's empty stderr golden omitted its two known class-property diagnostics
(captured under `remote-job-3112/results/t0-issue-json.log.gz`). With `set -e`,
the script stopped there, so smoke and T1 were not run. Slurm accounting was
disabled and no terminal status file was written; the captured runner output
ends at the JSON mismatch. All results and the full Slurm output were copied
here, then the 1.1 GiB disposable remote run tree was removed.
