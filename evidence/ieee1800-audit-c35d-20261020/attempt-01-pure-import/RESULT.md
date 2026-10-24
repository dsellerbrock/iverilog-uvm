# Result — pure imported functions

Paired-edition run on DAN-DESKTOP, Slurm job 3564, using pinned toolchain
`cc25756d1` (`iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`,
`vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`):

| Edition | Compile | C link | Run | User output |
| --- | ---: | ---: | ---: | --- |
| 2017 | 0 | 0 | 0 | `DPI BASIC TEST: PASS (6/6)` |
| 2023 | 0 | 0 | 0 | `DPI BASIC TEST: PASS (6/6)` |

The first output line matches the expected six pure-function results in both
editions. Each run also prints Icarus's normal source-location `$finish` line.
The harness compared the entire stdout file to the user-output-only golden,
so its `stdout_match` field is `NO` and its job exit status is 1. This is a
harness comparison mismatch, not a simulator failure; checking the expected
first line and exactly one `$finish` status line passes for both runs.

Raw versions, source copies, hashes, command timing, stdout, stderr, and diffs
are preserved in [`remote-3564/`](remote-3564/). No test source or golden was
changed. The result demonstrates legal pure imports and calls for integer
inputs/results only; it does not check optimizer call elimination or every
restriction on pure functions.
