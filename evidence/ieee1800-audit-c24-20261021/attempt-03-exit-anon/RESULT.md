# IEEE 1800 §§24.6–24.7 paired probe results

## Environment

- Slurm job 3653 on DAN-DESKTOP; requested 1 CPU, 1 GiB, 5 minutes. `sbatch --wait` returned 0 and `squeue -j 3653` was empty afterward. Slurm accounting is disabled, so elapsed time and peak RSS are unavailable.
- Protected toolchain: source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel, at `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Each compile/run used a 30-second timeout and `-B /home/dsell/toolchains/iverilog-fb584a25-20261020/lib/ivl`.
- SHA-256 values for `iverilog`, `vvp`, `ivl`, `ivlpp`, and every probe source are preserved in [`remote-3653/logs/slurm-3653.out`](remote-3653/logs/slurm-3653.out).

## Results

| Probe | `-g2017` | `-g2023` | Observation |
| --- | --- | --- | --- |
| edition flag control | Compile/run exit 0 | Compile/run exit 0 | Both edition flags work with the pinned toolchain. |
| #874 if-else property | Compile exit 3 | Compile exit 3 | Same standard-valid property is rejected; two `if` diagnostics and a dropped-property diagnostic. |
| §24.7 `$exit` | Compile/run exit 0; stdout `P1 5` | Compile/run exit 0; stdout `P1 5` | The other initial process and module event do not run. This agrees with §24.7 terminating all initial procedures in the originating program and §20.2's implicit `$finish` after program blocks complete. It conflicts with the expected behavior written in open issue #786; do not file a duplicate. |
| §24.6 anonymous program in a package | Compile exit 2, syntax error at `program;` | Compile exit 2, same syntax error | The legal anonymous-program construct is not accepted. |
| module reference control | Compile exit 2, same syntax error at `program;` | Compile exit 2, same syntax error | The control cannot reach the module reference; no visibility result is inferred. |

Exact compile and simulation output is in [`remote-3653/`](remote-3653/). The #874 edition limitation in the earlier §16.12.6 result is corrected: the paired control confirms both flags work on this toolchain. The anonymous-program module control is inconclusive because compilation fails earlier on the anonymous declaration.

## Standard basis

IEEE 1800-2017 and 1800-2023 §24.6 permit anonymous programs in packages or compilation-unit scopes to declare items in the shared programwide/program-wide namespace; Annex A's `anonymous_program` grammar starts with `program ;` and lists task declarations among its items. The tested package form is therefore a positive case. Both editions' §24.6 also say the programwide space is accessible only to programs. The following note about references outside a program block is informative; the module-reference control is retained only as an observation and did not compile past the anonymous declaration.

IEEE 1800-2017 and 1800-2023 §24.7 say `$exit` from an initial procedure in a program shall terminate all initial procedures and their descendants in that program block. Section 20.2 says: “The $exit control task waits for all program blocks to complete, and then makes an implicit call to $finish.”
