# IEEE 1800 §24.3 program-item paired probe results

## Environment

- Slurm job 3659 on DAN-DESKTOP, run directory `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3660`, partition `verilog`; requested 1 CPU, 1 GiB, 10 minutes. At submission, 18 of 20 CPUs were allocated. `squeue -j 3659` was empty after completion; Slurm accounting storage is disabled, so elapsed time and peak RSS are unavailable.
- Protected toolchain: Icarus 13.0-devel, source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, invoked with `-B /home/dsell/toolchains/iverilog-fb584a25-20261020/lib/ivl`.
- All 10 compile cases and the two positive runs completed without timeout. Source and binary SHA-256 values are in [`remote-3659/logs/a3-c24-items-3659.out`](remote-3659/logs/a3-c24-items-3659.out).

## Results

| Probe | `-g2017` | `-g2023` | Observation |
| --- | --- | --- | --- |
| Positive permitted items: typedef, class, variable, task, `initial`, `final`, and continuous `assign` | Compile/run 0; stdout `FIN` | Same | The tested permitted items elaborate and execute. |
| `always` in program | Compile exit 1: “Always statements are not allowed in program blocks.” | Same | Required error. |
| Module instance in program | Compile exit 1: “Module instantiations are not allowed in program blocks.” | Same | Required error. |
| Nested program declaration | Compile exit 1: “module, program, or interface declarations are not allowed in program blocks.” | Same | Required error. |
| Interface instance in program | Compile exit 1: “Module instantiations are not allowed in program blocks.” | Same | Required error. |

Full compile stdout/stderr and positive simulation outputs are preserved under [`remote-3659/logs/`](remote-3659/logs/). Probe sources and hashes are in [`input/`](input/); open/closed issue searches are in [`DEDUPE.md`](DEDUPE.md). All four negative cases are rejected in both editions, so this batch produced no new issue candidate.

## Standard basis

IEEE 1800-2017/2023 §24.3 permits initial and final procedures and prohibits always procedures, primitives, UDPs, and module/interface/program declarations or instances in a program block. The §24.3 Annex A grammar lists `continuous_assign` and `final_construct` as program items. The probes match those rules for the tested subset.

After recording the result and copying all logs locally, only this job's remote `build/` directory was removed; its `input/` and `logs/` remain.
