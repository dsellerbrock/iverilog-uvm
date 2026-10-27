# §8.26.2–§8.26.6.1 interface-class follow-up — first attempt

Slurm job 3493 ran the directed positive and six negative probes in both editions using Icarus 13.0-devel `cc25756d1`. Exact tables, full command logs, and the compiler version are preserved under `results/` and `logs/`.

The positive `p08_26_sub.sv` did not compile in either edition (rc 16), so it did not run. The first syntax errors point to the return types `IntfB#(bit)::T2` at lines 44 and 47; later `IntfC` errors are parser fallout. The lead confirms that this specialized class-scope typedef spelling is valid under Annex A and §8.23. A follow-up will separate specialized scope, inherited interface typedefs, and return-type position while completing the positive check.

The negative probes m1–m5 each failed in both editions with diagnostics matching their intended rules: type not inherited through `implements`, type parameter not allowed in an `implements` list, forward interface-class typedef not allowed in an `implements` list, interface-class handle cannot be constructed, and inherited non-virtual method does not implement a pure interface method.

The first m6 attempt also returned compile rc 1, but only because the source omitted a root module (`Unable to find the root module ...`). This is a harness defect, not evidence about nested interface classes. The follow-up adds a module that references the nested interface class and reruns both editions.

Open-and-closed searches requested by the audit lead are in `dedupe-open-closed.txt`. No issue was filed from this attempt; the positive compile failure and m6 harness error need the directed follow-ups before classification. IEEE 1800-2017 §§8.26.2–8.26.6.1, pp. 196–199, and the corresponding 2023 clauses govern this probe.
