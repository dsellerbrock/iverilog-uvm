# Exhaustive 4-state conversion fixture

The registered `sv_vpi_wide_index` fixture enumerates all 65,280 8-bit
0/1/X/Z values that contain at least one X or Z, and retains targeted signed,
unsigned, overflow, sign-extension, 65-bit tail, and wide X/Z cases.

Slurm job 1760 compiled and ran the final fixture against both the reference
and candidate installs from pinned base
`374b037e7c8fba7097e0b86b05be7956ca6b5487`. Both printed `PASSED`; stdout and
stderr matched. The raw job, compile logs, binaries, and source fixture are in
[`job-1760/`](job-1760/).
