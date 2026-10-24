# §20.18 miscellaneous system tasks/functions — 2026-10-20

IEEE 1800-2017 §20.18.1 and 1800-2023 §20.17.1 state that `$system` returns the C `system()` result as an `int` when used as a function. On POSIX, `exit 3` is returned as wait status 768. 2023 §20.17.2 specifies `$stacktrace` task and string-function forms; the stack contents are implementation-dependent. The 2017 edition has no `$stacktrace`. Exact references and bounded excerpts are in `STANDARD.md`.

## Run

- Slurm job 3544 on DAN-DESKTOP, cc25756d1; 1 CPU, 1 GiB, 15-minute limit; start 2026-10-20 12:55:56 UTC, end 12:55:57 UTC, `COMPLETED`, exit 0, elapsed 1 s.
- Each compile used `iverilog -B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl -g<edition> -s <module> -o <module>.vvp <module>.sv`; runnable files then used `vvp`. Each process had a 30 s timeout.
- Compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; helper and source hashes are in `slurm-3544.out`.
- Slurm accounting is disabled and completed-job `sstat` returned no data; peak RSS is unavailable. Requested memory was 1 GiB based on earlier similar probes.

## Results

- `p20_18_misc17` compiled and ran under both editions; exact output in each:
  ```text
  SYS_SIDE_EFFECT
  S0 0
  S3 768
  ```
- `p20_18_misc` compiled and ran under `-g2023`; output:
  ```text
  SYS_SIDE_EFFECT
  S0 0
  S3 768
  $stacktrace: call stack (innermost frame first):
    #0 p20_18_misc.leaf (.../p20_18_misc.sv:5)
    #1 p20_18_misc (location unavailable -- recompile with -pfileline=1 to see call-site lines for enclosing frames)
  ST 1
  ```
- The same file under `-g2017` was rejected with the edition diagnostic for both `$stacktrace` forms.
- Two-argument `$system` in `n20_18_system_arity` was rejected in both editions with `The $system function takes zero or one argument; found 2.`

## Issue dedupe

Open and closed issues were searched for `$system`, `$stacktrace`, `20.18`, and `20.17.2`; raw results are in `dedupe-*.json`. Closed #480 covers excess `$system` arguments. Closed #459 covers the 2023 `$stacktrace` string-function form. This run matches both issues; no new issue was filed. The reproducer results are recorded in [the #480 comment](https://github.com/dsellerbrock/iverilog-uvm/issues/480#issuecomment-6298749337) and [the #459 comment](https://github.com/dsellerbrock/iverilog-uvm/issues/459#issuecomment-6298751046).

The exact remote Slurm run directory was 15,899 bytes and was removed after recording these results here.
