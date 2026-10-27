# §8.5 / §6.24.1 scoped-type cast results

## Run provenance

- Host: DAN-DESKTOP, Slurm job 3718; 1 CPU, 1 GiB, 15-minute limit; each source/edition had a 60-second timeout.
- Toolchain: Icarus 13.0-devel, `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`; compiler SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`; VVP SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Each source was compiled/run in `-g2017` and `-g2023` with a separate 60-second process-group timeout. Per-case elapsed time rounded to 0.00 seconds; maximum RSS ranged from 8,420 to 11,464 KiB. The harness completed without timeout.

## Results

| Case | 2017 | 2023 | Raw result |
|---|---:|---:|---|
| K1 typedef `C#(3)::T` control | compile exit 2 | compile exit 2 | Syntax error in typedef clause. |
| K2 `C#(3)::T'(x)` | compile exit 4 | compile exit 4 | `A hierarchical reference (C.T') is not allowed in a constant expression`; then `Cast size expression must be constant and greater than zero.` |
| K3 `C#()::T'(x)` | compile exit 4 | compile exit 4 | Same specialized class-scope resolution and cast-size errors as K2. |
| K4 `P::T'(x)` | pass | pass | `PASS K4 value=1`. |
| K5 `pkg::T'(x)` | pass | pass | `PASS K5 value=1`. |

The non-parameterized class and package controls pass. K2 and K3 reproduce the existing #611 form and fail during elaboration in both editions. K1's typedef declaration fails in the same class-scoped specialized-type area already tracked by #766; the earlier §8.23 scope-type run has the same type-declaration limitation. No new issue is warranted from these probes; the cast behavior belongs on #611 and the typedef control overlaps #766.

Raw per-case logs and the job stdout are preserved in `results/` and `slurm-3718.out`.
