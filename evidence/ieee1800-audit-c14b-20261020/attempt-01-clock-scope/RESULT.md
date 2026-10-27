# Raw §14.7 results

| Edition | Probe | Compile expected/actual | Run exit | Output |
|---|---|---:|---:|---|
| 2017 | `sv_program_clocking_finish.v` | pass/0 | 0 | `PASSED` |
| 2017 | `sv_checker_basic.v` | pass/0 | 0 | `PASSED` |
| 2017 | `p14_07_clocking_checker.sv` | pass/0 | 0 | `CHECKER_CLOCKING_SCOPE_OK` |
| 2017 | `n14_07_clocking_compilation_unit.sv` | fail/2 | — | syntax error at clocking declaration |
| 2023 | `sv_program_clocking_finish.v` | pass/0 | 0 | `PASSED` |
| 2023 | `sv_checker_basic.v` | pass/0 | 0 | `PASSED` |
| 2023 | `p14_07_clocking_checker.sv` | pass/0 | 0 | `CHECKER_CLOCKING_SCOPE_OK` |
| 2023 | `n14_07_clocking_compilation_unit.sv` | fail/2 | — | syntax error at clocking declaration |

The full test command, compiler output, logs, hashes, and Slurm status are retained alongside this result.
