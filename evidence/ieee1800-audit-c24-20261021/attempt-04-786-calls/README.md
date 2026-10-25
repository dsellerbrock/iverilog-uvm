# IEEE 1800 §§24.4–24.5 and #786 paired probes

The assigned work is to rerun issue #786's exact reproducer, then test program-to-module subroutine calls and the required scheduling context of a module task called from a program. The negative case checks the §24.5 rule in the other direction.

## Standard text

IEEE 1800-2017 and 1800-2023 §24.5 say that a program subroutine call from a design module is illegal and “shall result in an error.” The same clause permits programs to call subroutines in design modules or other programs. When a program calls a task declared in a design module, that task “shall use the reactive region set” for its scheduling activities.

IEEE 1800-2023 §24.4 p.777 says the program construct schedules execution “in the Reactive region, after all design events have been processed, including clocks driven by nonblocking assignments.” IEEE 1800-2023 §24.5 p.778 says a program subroutine call from a design module “shall result in an error”; programs may call subroutines in modules, and a module task called from a program “shall use the reactive region set for its scheduling activities.” IEEE 1800-2017 §§24.4–24.5 have the corresponding rules. The positive probe checks that the call works and its NBA update is visible after return; this output is consistent with the required scheduling but does not isolate the exact region. The negative probe checks the forbidden call direction.

For #786, the exact issue source places both `initial` procedures inside the same `program pg`; `PROG2` is only a display label. IEEE 1800-2017/2023 §24.7 says `$exit` terminates all initial procedures and descendants in its originating program. Section 20.2 says `$exit` waits for all programs to complete and then implicitly calls `$finish`. Thus the second initial process is terminated, and this single-program case should print neither `PROG2 done` nor `LATE`.

## Execution

The exact source snapshot is at repository HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` plus the three uncommitted probe files preserved in `input/`; their SHA-256 hashes are recorded there. Slurm job 3655 uses the protected `fb584a251` toolchain, 1 CPU, 1 GiB, and a 5-minute limit. Each compile and simulation has a 30-second timeout. The job was submitted to the isolated run directory `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3654`; scheduler result, binary hashes, and raw outputs will be recorded in `RESULT.md`.

The open+closed dedupe covers `program task module`, `24.5`, and `24.4` plus related wording searches; see `DEDUPE.md`. The lead classified the forbidden module-to-program call as PARTIAL and filed [#877](https://github.com/dsellerbrock/iverilog-uvm/issues/877); the program-to-module direction is supported in the tested subset.
