# Clause 16.18 clocking-block assertion probes

Lead-selected probes for IEEE 1800-2017 §16.18 p. 482 / IEEE 1800-2023 §16.18 pp. 501–502 and the related §16.5.1 clocking-input sampling rule (2017 p. 375 / 2023 p. 394). The standard says a clocking-block variable used in a concurrent assertion is sampled only in the clocking block, and all four assertions in its example are equivalent. A separate rule requires clocking-block input variables to use `#1step` sampling and requires an error for any other sampling type.

K1 and K2 isolate standard examples a1/a3 with the same data and edge; both should report only `FAIL 15`. K3 reproduces the standard a2/a4 clocking-block property declarations, which are expected to be blocked by existing #917 parser gap. E1/E2 verify that `#3` and `#0` input sampling are rejected.

Each source is independent. Both editions use assertions and the pinned compiler; every compile and run is capped at 30 seconds. Slurm job 3758 completed. Raw logs, hashes, scheduler metadata, and detailed results are in [`RESULT.md`](RESULT.md) and `raw-slurm-3758/`; the open/closed issue snapshot and search are in [`DEDUPE.md`](DEDUPE.md). The lead filed [#919](https://github.com/dsellerbrock/iverilog-uvm/issues/919) for K2 and [#920](https://github.com/dsellerbrock/iverilog-uvm/issues/920) for E1/E2.
