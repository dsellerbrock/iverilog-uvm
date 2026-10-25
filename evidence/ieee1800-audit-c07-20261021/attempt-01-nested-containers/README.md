# Clause 7 nested/container interaction probes

Lead-selected paired probes for IEEE 1800-2017/2023 §7.8, §7.10, §7.12.1–§7.12.3, and the §12.7.3 `foreach` interaction. The UVM graph points to `uvm_pool`'s associative storage and iteration methods, and `uvm_queue`'s typed queue storage and operations; this tranche checks the nested combinations absent from the Clause 7 matrix. Probes are intentionally separate and do not modify regression goldens.

Run all ten inputs under `-g2017` and `-g2023` with the pinned Icarus toolchain, 1 CPU / 1 GiB, and a 30-second limit for each compile and run. Slurm job 3760 completed; nine cases match their expected outputs. A8's class-queue reduction is excluded from conformance claims because §7.12.3 restricts reductions to unpacked arrays of integral values. Raw logs and detailed outcomes are in [`RESULT.md`](RESULT.md) and `raw-slurm-3760/`; the complete open/closed issue search is in [`DEDUPE.md`](DEDUPE.md).
