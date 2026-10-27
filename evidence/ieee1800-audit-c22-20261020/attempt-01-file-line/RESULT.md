# IEEE 1800 §22.13 file and line macro probe

## Standard basis

IEEE 1800-2017 and 1800-2023 §22.13 define `__FILE__` as the current input
file name and `__LINE__` as its current line number. Both editions state that
an include changes these values to the included file and that processing
returns to the including file's path and the line after the include. The
relevant wording is the same in both editions.

## Probe and result

- Existing regression: [`br_gh782a.v`](../../../ivtest/ivltests/br_gh782a.v) and included [`br_gh782a.vi`](../../../ivtest/ivltests/br_gh782a.vi), already registered in `ivtest/regress-sv.list` with `br_gh782a.gold`.
- Slurm job 3600 used the current-main compiler at `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel), one CPU and 1 GiB. It compiled with `-g2012`, ran VVP, and diffed the output against the checked-in golden. Compile, run, and diff all passed; the complete standard include-location sequence matched exactly.
- Each command had a 30-second timeout. The source and expected-output hashes are recorded in [`slurm-3600.out`](remote-3600/slurm-3600.out); stdout, stderr, and raw Slurm output are retained in [`remote-3600/`](remote-3600/).
- The current-main compiler accepts `-g2012` but does not expose `-g2017` or `-g2023` flags. The §22.13 text is the same in both editions, and this probe uses no edition-specific syntax.
- This covers include-location updates and restoration only. The `line` directive, other compiler directives, and the full §22 surface remain unassessed.

## Lead status

This passing subset is recorded for lead classification. No conformance-gap
issue was proposed from this result.
