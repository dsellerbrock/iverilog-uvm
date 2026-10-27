# §8.23 / §8.26 type-scope isolation — combined attempt

Slurm job 3494 ran both editions with pinned Icarus 13.0-devel `cc25756d1`.

The corrected §8.26 positive compiled and ran in both editions. Output:

```text
K1 1 0
Ext
K3A 1 2
K3 1
K4 1 1 0
K5 1 1
```

This confirms inherited virtual implementation, interface dispatch overriding an inherited non-virtual method, inherited `T2` in an extending interface class, explicit `IntfC::t1_t` access, handle assignment and casts, and one implementation satisfying same-signature methods from two interfaces.

The combined S1–S5 type-scope probe failed to compile in both editions (rc 10). The first diagnostics point to S1–S3 variable declarations at lines 15–17; subsequent errors are at function return types S4/S5. The combined file does not isolate which forms cause the failure, so [attempt 03](../attempt-03-splits/) compiles each form separately.

The corrected m6 probe now selects a root module and fails in both editions with the specific diagnostic `Nested class 'Inner' is not allowed in an interface class.` This confirms the nested-interface-class restriction.

Dedupe in `dedupe-open-closed.txt` found [#766](https://github.com/dsellerbrock/iverilog-uvm/issues/766), an existing open issue that covers specialized class-scope typedef use in variable, typedef, and class-property declarations. It explicitly leaves function-return use unassessed. S1–S3 overlap that existing issue; S4/S5 will establish whether the return-type boundary is also affected. No issue was filed from the combined compile failure.
