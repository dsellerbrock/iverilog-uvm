# IEEE 1800 §7.12.4 and §7.12.5 probes

The next lead-directed probe covers the optional array-iterator index argument in §7.12.4 (both editions) and `map()` in §7.12.5 (2023 only).

- [`p07_12_4_iterarg.sv`](../../../../tests/1800_audit/c07/p07_12_4_iterarg.sv) checks the standard example pattern where a struct member named `index` conflicts with the default iterator index name. Its three stored `index` values are 7, 1, and 9 while their queue positions are 0, 1, and 2; the 2023 example requires `I1 2 10`. A separate no-second-argument control is in [`p07_12_4_iterarg_control.sv`](../../../../tests/1800_audit/c07/p07_12_4_iterarg_control.sv).
- [`p07_12_5_map.sv`](../../../../tests/1800_audit/c07/p07_12_5_map.sv) uses the three 1800-2023 standard examples and adds associative-key and fixed-array-range checks. Expected 2023 output:

```text
M1 2 3 4
M2 4 6 9
M3 1 1 0 1
M4 2 10 20
M5 3 5 8
```

`map()` is new in 1800-2023; the 2017 compile is expected to reject it. The 2023 §7.12.5 text says mapped arrays preserve the source range or associative key set and use the self-determined type of the `with` expression. The optional iterator-index argument is present in 2023 §7.12.4, but not in 2017 §7.12.4, so the two-argument form is only required in 2023. Exact edition wording and page references are recorded in [`STANDARD.md`](STANDARD.md).

## Slurm result

Job `3519` used one CPU, 1 GiB, and a five-minute limit with pinned Icarus 13.0-devel (`cc25756d1`) from shared toolchain `iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`. The compiler and runtime hashes are in [`slurm-3519.out`](slurm-3519.out). `map()` compiles and runs under `-g2023`, printing the five expected lines. Under `-g2017`, all five `map()` calls receive the required edition diagnostic. The iterator-index form is rejected by Icarus under both editions; the 2017 rejection is expected, while the 2023 rejection is the candidate gap.

A plain `find()` control passes in both editions, printing `C1 2 20`; see [`attempt-02-index-control/RESULT.md`](../attempt-02-index-control/RESULT.md). This confirms that the 2023 failure is specific to the optional iterator-index argument, not the queue-of-struct `find()` receiver.
