# IEEE 1800 Clause 28 isolated switch results

## Environment

- Slurm job 3662 on DAN-DESKTOP; 1 CPU, 1 GiB; `JobState=COMPLETED`, `ExitCode=0:0`, `RunTime=00:00:01`.
- Protected Icarus 13.0-devel toolchain, source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; executable and library SHA-256 values are in [`remote-3662/a3-c28-notri-3662.out`](remote-3662/a3-c28-notri-3662.out).
- Both sources compiled and ran successfully under `-g2017` and `-g2023`; hashes are in the raw Slurm output and sources are in [`input/`](input/).

## Results

| Probe | Expected (2017 and 2023) | Actual `-g2017` | Actual `-g2023` |
| --- | --- | --- | --- |
| nmos, pmos, rnmos from supply, and tran | `S St1 HiZ Pu1 St0` | `S St1 HiZ St1 St0` | Same |
| pullup through rnmos; cmos with both channels on and data 0 | `R We1 St0` | `R St1 St0` | Same |

The nmos, pmos, tran, and cmos outputs match their standard rules. Both rnmos checks retain strong strength: the supply input remains `St1` rather than reducing to `Pu1`, and the pullup input remains `St1` rather than reducing to `We1`.

## Standard basis and dedupe

IEEE 1800-2017/2023 §28.13 says nonresistive nmos/pmos/cmos pass input strength except supply becomes strong; tran leaves strength unchanged except supply becomes strong. §28.14 Table 28-8 maps supply to pull and pull to weak through resistive devices. Both expected rnmos results follow that table. §28.9—not §28.7—defines cmos as the combination of pmos and nmos; §28.7 Table 28-6 supplies those switches' on/off truth behavior. The citations and page numbers are in [`README.md`](README.md).

Open+closed searches for `nmos`, `tran`, `rnmos`, `trireg`, `charge decay`, `28.13`, and `cmos` were run with limit 1000. #878 matches the broad first six queries but covers only unsupported `trireg`; it does not cover resistive strength reduction. `cmos` found no issues. See [`DEDUPE.md`](DEDUPE.md).

The raw output and per-case logs are under [`remote-3662/`](remote-3662/). The remote build directory was removed after copying the evidence; its inputs and logs remain.
