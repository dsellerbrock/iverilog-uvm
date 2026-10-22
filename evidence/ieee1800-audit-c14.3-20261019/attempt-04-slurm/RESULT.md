# Attempt 04 — Slurm build stopped before probes

- Source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`, plus the staged §14.3 probes.
- Slurm job 3150 requested 3 CPUs / 2 GiB. The build ran 1:16.77 and ended with `g++: fatal error: Killed signal terminated program cc1plus` while compiling `elaborate.o`; Slurm recorded an OOM-kill event. `/usr/bin/time` recorded 1,445,884 KiB max RSS before termination.
- No probes ran; this is a resource failure, not a conformance result.
- The T0/T1 build for #671 on the same host completed with 2 CPUs / 3 GiB and 1,663,008 KiB max RSS, so the next audit attempt requests 3 GiB and uses 2 CPUs.
- Raw Slurm output and result logs are under `results-3150/`; remote and local hashes match.
