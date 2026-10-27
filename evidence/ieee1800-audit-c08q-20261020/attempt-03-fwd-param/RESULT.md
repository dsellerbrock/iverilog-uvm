# §8.27 parameterized forward class typedef (Slurm job 3508)

The probe extends the IEEE 1800-2017/2023 §8.27 example with observable assignments to a `T` property. Positional (`C#(1, real)`) and named (`C#(.p(2), .T(real))`) overrides preserve real values; a default (`C#()`) specialization uses `T=int`.

- Host: DAN-DESKTOP, job 3508; 1 CPU, 1 GiB.
- Toolchain: Icarus 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Command: `iverilog -g2017|-g2023 -s top -o <image> p08_27_fwd_param.sv`, then `vvp <image>`. Each command had a 30-second timeout.

| Edition | Compile | Run | Stdout | Result |
|---|---:|---:|---|---|
| 2017 | 0 | 0 | `FP 1 2 2 1.50 2.25 2` | PASS |
| 2023 | 0 | 0 | `FP 1 2 2 1.50 2.25 2` | PASS |

This confirms the forward typedef accepts the parameterized class, both override forms resolve correctly, and the omitted type override uses the default type. The earlier `$bits(real)` observation from job 3506 was not used as a §8.27 assertion; see that attempt's lead-review addendum.

Raw results: `results-3508.tar.gz`; source/tool checksums: `results/SHA256SUMS`; scheduler output: `logs/job-3508.out`.
