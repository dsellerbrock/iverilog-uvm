# #680 focused gate — initial harness attempt

- Slurm job 2882 on DAN-DESKTOP, 3 CPUs, 6 GiB, 3:16 elapsed; controller exit `1:0`. Slurm accounting does not retain peak RSS.
- Base commit: `82023726be90ab269d6e0ef5e755ebb69e6f648c`.
- Built Icarus 13.0 devel. Installed compiler SHA-256: `8702a2c3ad056fb0c7e77cb47d0821d6f9ce31d09aeb719e9db0e57d7c269f92`; VVP SHA-256: `91165dbc60ff9646e0424f6849f3a72c099a59663948f6a3e5a525f4eff3e4db`.
- Issue reproducer passed in both `-g2017` and `-g2023`.
- T0 smoke gate did not pass: its Perl smoke subsets reported 56/56 and 133/133, but helper scripts could not find the compiler/runtime at the in-tree paths because this attempt built out of tree. The overall smoke command returned failure.
- T1 legacy constraint-function suite passed 228/228. The two new JSON positive cases ran and produced the expected `PASSED` output, but failed comparison because the split-stream `sv_constraint_function_package_inline-vvp-stdout.gold` fixture was missing.
- This is a failed harness/fixture attempt, not passing T0/T1 evidence. Raw Slurm logs and per-test outputs are in `a3-680-attempt-03-initial.tar.gz`.
- Exact runner script is retained under `../attempt-03-fixed/build-and-t1.sbatch`.
- Follow-up safety reproducer: the old installed compiler incorrectly accepted a package function argument `this.data` in both editions. It is now added as a paired 2017/2023 expected compile-error regression.
