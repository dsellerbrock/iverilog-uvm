# Result — procedural checker instance (§17.3)

- Source: `input/p17_03_procedural_checker_instance.sv`
- Host/job: DAN-DESKTOP, Slurm job 3588, 1 CPU, 1 GiB, 5-minute limit.
- Compiler: Icarus 13.0 devel `cc25756d1`; compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`.
- Control: existing `sv_checker_basic.v` static checker test compiles and runs in both editions, stdout `PASSED`.

| Edition | Procedural checker compile | Runtime | Static control |
| --- | --- | --- | --- |
| `-g2017` | exit 2; line 10 syntax error, `Malformed statement` | not reached | compile/run exit 0, `PASSED` |
| `-g2023` | exit 2; line 10 syntax error, `Malformed statement` | not reached | compile/run exit 0, `PASSED` |

The source line rejected is `p17_03_checker instance(clk, sig);` inside the module `initial` procedure. Slang 11.0.448 also rejects the same source with exit 1 in both editions, so it is not an independent passing oracle. The standard basis is explicit: §17.3 distinguishes a checker instantiated inside procedural code as a “procedural checker instance”; the two listed restrictions exclude fork-join and a procedure of another checker, neither of which applies here. This remains a candidate for lead classification, not a filed issue.

Raw compiler/runtime logs, versions, source/binary hashes and the Slang output are adjacent. The short compile/run timeout was 30 seconds per case.
