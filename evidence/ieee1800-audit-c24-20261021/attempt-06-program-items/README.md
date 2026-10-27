# IEEE 1800 §24.3 program-item paired probes

This batch checks the item rules for a program declaration in both editions. The positive case exercises permitted procedural, final, data, class, task, and continuous-assignment items. Four negative sources each exercise one prohibited construct.

## Standard text

IEEE 1800-2017 §24.3 says a program may contain “initial or final procedures” and “shall not contain always procedures, primitives, UDPs” or “declarations or instances of modules, interfaces, or other programs.” IEEE 1800-2023 §24.3 gives the same exclusions. Annex A's `non_port_program_item` grammar includes `continuous_assign` and `final_construct` in both editions, so the positive case includes `assign w = 1'b1;` and `final $display("FIN");`.

## Execution

Each of the five sources is compiled under `-g2017` and `-g2023`; only the positive source is run. Slurm job 3659 uses the protected `fb584a251` toolchain, 1 CPU, 1 GiB, a 10-minute ceiling, and a 30-second timeout per compile/run, in `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3660`. The source snapshot is repository HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` plus the five probe files preserved in `input/`. Open+closed dedupe covers `always in program`, `program instance module`, `nested program`, and `24.3`; see `DEDUPE.md`. Final results, hashes, and raw output are in `RESULT.md`.
