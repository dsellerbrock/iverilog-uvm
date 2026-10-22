# IEEE 1800 §§16.12.1–16.12.7 corrected probe rerun

The first positive test verified all four implications/conditional outcomes but used an unsupported cover-action counter as its sequence hit oracle. This rerun keeps the direct sequence-as-property cover and adds a nonvacuous assertion using the named sequence as its consequent; its failure count now checks the actual property behavior. It also reruns the mismatched `endproperty` label negative control.

- Slurm job: `3204` on `DAN-DESKTOP`, 2026-10-19 15:55 MDT; request was 1 CPU, 1 GiB, 10 minutes. The job started and finished in the same second; its remote run directory was removed after copying results.
- Toolchain: Icarus from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; binary hashes are in `results/sha256.txt`.
- `p16_12_01_07_core_properties.sv` compiled and ran exit 0 under both editions, printing `PASSED: §§16.12.1–16.12.3, 16.12.6–16.12.7 core properties`. Triggered overlapped and nonoverlapped implications, sequence-as-property matching, negation, and both `if/else` branches were checked by explicit failure counters.
- `n16_12_endproperty_mismatch.sv` compiled and ran exit 0 under both editions despite `p_correct` ending with `endproperty : p_mismatched`. IEEE 1800-2017/2023 §9.3.4 says an end name that differs from the opening block name is an error; the label check is a conformance gap.
