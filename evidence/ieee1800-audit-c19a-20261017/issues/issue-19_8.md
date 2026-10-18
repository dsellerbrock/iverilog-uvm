Clause: 2017 §19.8 Table 19-5 and §19.11 / 2023 §19.8 Table 19-5 and §19.11 (2017 p. 587 / 2023 p. 615).

Requirement: Table 19-5 defines the two-argument forms. §19.11(d) gives the zero-denominator exception: “If get_coverage or get_inst_coverage is called with two arguments, zero is assigned to both arguments—the numerator and the denominator.” Outside that case, the methods report covered and defined bin counts.

Probe: `tests/1800_audit/c19/p19_05_bins_cov.sv`, using the bisection variant without the array-default bin. Evidence: `evidence/ieee1800-audit-c19a-20261017/results.txt`.

Observed: `g1.get_inst_coverage(n, d)` returns 7.142857 (5/70), but leaves `n=0,d=0`. The same occurs for `cg3`: 33.333333 (1/3), `n=0,d=0`.

Expected: `n=5,d=70` and `n=1,d=3`. Callers reading these output arguments currently receive incorrect counts.
