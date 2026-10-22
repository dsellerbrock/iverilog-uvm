# IEEE 1800 §§24.5 and 24.7 paired probe results

## Environment

- Slurm job 3655 on DAN-DESKTOP, partition `verilog`; requested 1 CPU, 1 GiB RAM, 5 minutes. At submission, 18 of 20 CPUs were allocated; the short job completed and `squeue -j 3655` was empty. Slurm accounting storage is disabled, so no accounting elapsed time or peak RSS is available.
- Pinned read-only toolchain: source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-fb584a25-20261020`; `-B /home/dsell/toolchains/iverilog-fb584a25-20261020/lib/ivl`.
- Every compile and simulation used a 30-second timeout. All six compile/run pairs exited 0 with empty stderr. Source and binary SHA-256 values are in [`remote-3655/logs/a3-c24-calls-3655.out`](remote-3655/logs/a3-c24-calls-3655.out).

## Results

| Probe | `-g2017` | `-g2023` | Observation |
| --- | --- | --- | --- |
| #786 issue-body source: `$exit` in one program initial, second initial in that same program, plus a module `LATE` process | Compile/run 0; empty stdout | Compile/run 0; empty stdout | `PROG2 done` is correctly terminated by §24.7. This source does not demonstrate a conformance gap; the module-origin variant in the prior #786 comment is a separate case. |
| Program calls module task containing `@(posedge clk); v <= 1'b1` | Compile/run 0; `RETURN 5 0`, `DESIGN 5 1`, `NEXT 15 1` | Same | The call works, and the NBA update becomes visible after the task returns. The output is consistent with the §24.5 scheduling rule but does not isolate the exact region. |
| Design module hierarchically calls a program task | Compile/run 0; stdout `HELLO` | Same | The call is accepted even though §24.5 says a design-module call to a program subroutine shall result in an error. The lead classified this PARTIAL and filed [#877](https://github.com/dsellerbrock/iverilog-uvm/issues/877) after the open/closed dedupe. |

Exact stdout/stderr and compile exit summaries are preserved in [`remote-3655/logs/`](remote-3655/logs/). The exact issue #786 body source and both §24.5 probes are in [`input/`](input/).

After recording the results, I removed only this job's generated remote `build/` directory; the isolated run's `input/` and `logs/` remain. I posted the §24.7 correction for the issue-body source at [#786 comment](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309531937) and left the issue open because its earlier comment describes a distinct module-origin `$exit` case.

## Standard basis

IEEE 1800-2017/2023 §24.5: “Calling program subroutines from within design modules is illegal and shall result in an error.” The same clause permits programs to call tasks in design modules and requires the called task to use the Reactive region set. Section 24.4 explains that the program construct schedules execution in the Reactive region after design events, including clocks driven by nonblocking assignments. IEEE 1800-2017/2023 §24.7 requires `$exit` to terminate all initial procedures and descendants in its originating program; §20.2 then waits for program blocks to complete before the implicit `$finish`.
