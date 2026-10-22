# IEEE 1800 §12.7–§12.8 probe evidence

Runs used the local Icarus build from `b9441bafbdb0b6b7413c09e0381845e69481391b` on macOS ARM64, wrapped with `~/codex-supervisor/localrun`. Tool hashes are recorded in each attempt directory. Editions were tested separately with `-g2017` and `-g2023`.

## Attempt 01: combined probe

`tests/1800_audit/c12/p12_07a_loops_jumps.sv` compiled in both editions. The 2017 runtime produced no output and timed out after 180 seconds. The 2023 runtime also produced no output; it was still consuming one CPU when the outer 300-second `localrun` limit expired. That outer wrapper stopped the harness but left the nested VVP process alive. Its process record is preserved in `attempt-01-loop-jump-probes/orphan-runtime.txt`; A3 sent SIGTERM to that process. This attempt has no positive-result conclusion.

The initial combined probe also had an incorrect oracle: it contained 24 checks, not 25, and `foreach (A[i,,k]) cnt+=i` with `int A[2][3][4]` evaluates to 4, not 12. The isolated control in attempt 02 confirms 4 in both editions. The combined result must not be used for classification.

## Attempt 02: isolated hang bisect

Nine isolated controls compiled and ran in both editions. `do_assoc=3`, `forever=3`, `fork_loc sum=33`, `multi s=4`, `noexpr=3`, `queue=14`, `while_sh=5`, and `x_for=0` matched expectations. The bounded X-repeat control printed `x_repeat cnt=6` in both editions; §12.7.2 p.315 requires an X repeat count to be treated as zero. The lead classified this as a distinct gap and filed [#782](https://github.com/dsellerbrock/iverilog-uvm/issues/782); nearby [#655](https://github.com/dsellerbrock/iverilog-uvm/issues/655) covers only repeat event controls.

Each compiler/runtime invocation had a 10-second `localrun` timeout. The whole diagnostic took 2.32 seconds, with 8,208,384 bytes maximum resident set size. Per-case logs, source hashes, runner, and host record are in `attempt-02-hang-bisect/`.

## Attempt 03: focused negative recheck

Seven probes were accepted in both editions: foreach loop-index write, a loop variable sharing the array name, excess foreach loop variables, for-loop variable escaping its scope, a second excess-index form, `break` crossing a fork-join boundary, and `continue` crossing one. The lead filed [#783](https://github.com/dsellerbrock/iverilog-uvm/issues/783) for the three §12.7.3 restrictions and [#784](https://github.com/dsellerbrock/iverilog-uvm/issues/784) for §12.8; the for-scope case was added to existing [#767](https://github.com/dsellerbrock/iverilog-uvm/issues/767) after both-edition logs confirmed the unresolved `i` warning. Commands and per-case logs are in `attempt-03-negative-recheck/`.

## Attempt 04: issue dedupe

All searches used `gh issue list --state all --limit 40`; raw results are in `attempt-04-dedupe/gh-issue-search.txt`. Closed #487 covers packed foreach ranks and omitted array dimensions but not loop-variable read-only, same-name, or excess-variable rules. The lead reviewed #655 as non-covering because it concerns repeat event controls under §9.4.5, not procedural `repeat`.

The corrected combined probe `p12_07b_loops_jumps.sv` compiled in both editions and printed `FAIL repeat_x` / `RESULT pass=23 fail=1`; all other 23 checks passed. The isolated X-repeat control confirms the failure. The corrected case counts foreach array elements without invoking the separately tracked fixed-array string `len()` gap #734. Evidence and raw outputs are in `attempt-05-corrected-combined/`.

Current cumulative audit total: 53 new issues above the 89-issue baseline; open labeled count 142. New counts are §6: 36, §10: 2, §11: 8, §12: 7 (#778–#784, excluding existing #767).
