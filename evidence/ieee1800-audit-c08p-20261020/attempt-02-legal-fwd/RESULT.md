# IEEE 1800 §§8.20 and 8.27 probes (Slurm job 3504)

Host DAN-DESKTOP; Icarus 13.0-devel source `cc25756d1`. Toolchain versions and binary/source hashes are in the raw result archive; archive SHA256: `955d6c4e7e63030533080f422fa99c3afdba0266642a5f36e558c5cd3d3046e3`. Each compile and run was limited to 30 seconds.

## §8.20 method specifiers

The corrected legal 2023 Example 3 control compiles and runs under `-g2023` with the expected output:

```
B.f1
A.f2
ConcreteB.f3
A.f4
ConcreteC.f3
C.f5
```

All five Example 3 declarations marked “NOT OK” and the three additional negatives reject under `-g2023`. The legal source rejects under `-g2017` as required for edition-specific syntax. The first attempt copied Example 3's `class base;` line verbatim and failed because of the pure virtual method. Per the tech lead's §8.21 standards review, this is an editorial slip in the example; this rerun changes only that declaration to `virtual class base;`, then adds concrete subclasses that implement `f3` before construction. The change isolates §8.20 without treating the editorial error as a simulator gap.

## §8.27 forward class typedefs

The coupled forward references plus parameterized forward class handle compile and run in both editions, printing `FWD 2 1 8`. A forward class typedef left unresolved rejects in both editions with “Forward typedef `Missing` does not resolve to a data type in the same scope.”

Open+closed dedupe terms: `typedef class`, `forward class`, `forward typedef parameterized class`, and `8.27`. #760 is the nearest open issue but covers class-scope type selection via `typedef C::T`, a distinct behavior. #762 (wrong forward type kind), #751 (module type-parameter `forward_type`), #766 (specialized class-scoped type selection), and #19 (closed broad tracker with forward structs) were reviewed and do not duplicate these cases; remaining results are unrelated. Search output and issue reviews are preserved in this directory.

The lead classified the §8.20 method specifiers as IMPLEMENTED (tested subset; closed #455) and §8.27 typedef class as IMPLEMENTED (tested subset). Issue count remains 113. The matrix now records §8.1–8.3, §8.27–8.29 dispositions. The next lead-selected batch adds the standard parameterized-forward example and probes §8.30 weak references.
