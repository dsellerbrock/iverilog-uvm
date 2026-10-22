# IEEE 1800 §24.7: `$exit` called outside a program

Probe the §24.7 rule that calls to `$exit` from a thread not originating in a program initial procedure are ignored. The existing paired test includes both a module call and a separate program instance; the expected behavior is `EX0`, followed by `PROG done`, then implicit simulation completion before `LATE`.

Source: `input/r20_02_exit.sv`. Standard text was checked in both IEEE 1800-2017 and 1800-2023 §24.7. Open/closed dedupe found existing issue #786, whose body already records this module-call behavior, so this is supporting evidence for #786 rather than a new issue candidate.

Slurm job 3612 completed with the results in `RESULT.md`; remote run directory `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-004`; pinned toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020` (`fb584a251dd4cc91e56a75be662ccd5ee05c64e9`), 1 CPU, 1 GiB, 5-minute limit, 30-second timeout per compile/run.
