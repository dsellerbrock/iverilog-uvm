# §21.4.1 dynamic-array and queue probe

## Run provenance

- Host: DAN-DESKTOP, Slurm job 3717; 1 CPU, 1 GiB, 4-minute limit; per-edition 60-second timeout.
- Input: `tests/1800_audit/c21/p21_04b_dynqueue.sv` unchanged. It allocates a 2-element dynamic array and a 2-element queue, then reads a three-word file. Expected: load the first two values into each argument, keep both sizes at 2, accept `$writememh` on the dynamic array, and pass the round-trip check. A warning for the extra file word is acceptable.
- Toolchain: Icarus 13.0-devel, `iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`; Icarus SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`; VVP SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`. Current `origin/main` 10f3a0 does not change `vvp/vvp_readmem.c` from the pinned toolchain source.
- Per-edition command: `iverilog -g<2017-or-2023> -s p21f -o p21f.vvp p21_04b_dynqueue.sv && vvp p21f.vvp`, wrapped in a 60-second timeout.

## Results

Both editions compile successfully, then VVP exits 1 at runtime with the same four errors: `$readmemh` rejects the dynamic-array argument, `$readmemh` rejects the queue argument, and `$writememh` plus the following `$readmemh` reject the dynamic-array argument. The expected `RESULT pass=3 fail=0` line is not printed. The generated VVP files confirm compilation completed; the runtime failure is not a parser or compile failure.

Measured per-edition elapsed time was 0.00 seconds (rounded), with maximum RSS 11,448 KiB for 2017 and 11,572 KiB for 2023. The harness completed without a timeout. Overall job exit was zero for harness completion; each simulator run returned 1 as the probed behavior.

The runtime behavior violates IEEE 1800-2017 and IEEE 1800-2023 §21.4.1. Open/closed dedupe found no existing issue beyond associative-array issue #803. New issue filing is pending the audit lead.
