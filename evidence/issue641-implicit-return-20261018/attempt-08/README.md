# Issue #641 T0/T1 evidence

- Host: DAN-DESKTOP, Slurm job 2769, 2026-10-18.
- Command: `sbatch --parsable --wait t0t1.sbatch`.
- Resources: 3 CPUs, 5 GiB requested; runtime 3:01; exit code 0.
- Base: `c344d20197a569dea8936bad95de3d185b1e78dc` plus the patch recorded in `logs-job-2769/inputs.txt`.
- Build: passed. Icarus SHA-256 `104ec01cb29ac204f4f3380697f8ac5da57e685d58db3b3203883710b3c68daf`; VVP SHA-256 `6f67eb48b88863d0fd25dcfff3349a30a2002d28faf88b32d848f05774171d9d`.
- Issue reproducer: compiled and ran successfully with both `-g2017` and `-g2023`.
- T0 smoke: passed.
- T1: 10 selected legacy cases and 7 selected JSON cases passed.
- Peak RSS: unavailable; DAN-DESKTOP Slurm accounting storage is disabled.

The PR includes the job inputs/results and smoke, reproducer, and T1 output logs.
Configure, build, and install logs remain in the local evidence directory; they
are omitted from the PR because they contain generated command lines with
trailing spaces. The build result and compiler hashes above record their outcome.
