# Clause 7 associative-array probe

Scope: IEEE 1800-2017/2023 §§7.8.3, 7.8.5, 7.9.9, and 7.9.10. The probe checks class and unpacked-struct index types, derived and null class keys, copy assignment, by-value copying, `ref` aliasing, and rejection of incompatible associative/fixed-array subroutine formals.

Expected positive output, subject to the standard-confirmed object-key semantics:

```text
A1 4 1 3 1 4
A2 2 5 0
A3 1 9
A4 1
A5 200
```

Both negative files should fail compilation: one uses an associative formal with a different index type; the other uses a fixed-array formal.

Attempt 1 was invalid because the struct assignment pattern was passed directly to `exists()` without a type context; it failed before exercising the intended behavior. The negative formal compatibility probes did exercise the intended boundary and were rejected in both editions. The corrected positive probe assigns the key to a typed `U` variable before calling `exists()` and is rerun in `attempt-02-assoc-typed-pattern/`.

Runner: pinned Icarus toolchain `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, both `-g2017` and `-g2023`. Each compile/run command has a 30-second timeout. Source checkout HEAD and dirty state are recorded in `RESULT.md` after the run.
