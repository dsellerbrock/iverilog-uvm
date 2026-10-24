# §8.30 weak-reference probe results (Slurm job 3505)

- Host: DAN-DESKTOP, uptime about 6 days at run time.
- Compiler: Icarus Verilog 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Command form: `iverilog -g{2017,2023} -s <probe> -o <image> <source>`; each compile/run capped at 30 seconds. Job requested 1 CPU, 1 GiB.

| Edition | Probe | Result |
|---|---|---|
| 2023 | `p08_30_weak.sv` | Compile rejected at both `weak_reference#(T)` typedefs (syntax error in typedef clause). |
| 2023 | `p08_30_weak_std.sv` | Compile rejected at both `std::weak_reference#(T)` typedefs (syntax error in typedef clause). |
| 2017 | `p08_30_weak.sv` | Same syntax rejection; records observed 2017 behavior, not a 2017 conformance claim. |
| 2023 | `n08_30_weak_int.sv` | Rejected as unknown module type `weak_reference`; this is not a meaningful type-constraint diagnostic because the feature itself is unrecognized. |

Both positive spellings fail before runtime, so the required lifetime/get/get_id behavior is unimplemented. Existing open issue [#461](https://github.com/dsellerbrock/iverilog-uvm/issues/461) already directly tracks `weak_reference#(T)` support. Open+closed dedupe is in `dedupe-open-closed.txt`; do not file a duplicate. The separate §8.27 parameterized-forward results in job 3505 are invalid because the harness selected `-s p08_27_fwd_param` while the probe declares `module top`; job 3506 reruns that exact probe with the correct root.

Raw outputs: `results-3505.tar.gz`; source and binary checksums: `results/SHA256SUMS`; job log: `logs/job-3505.out`.
