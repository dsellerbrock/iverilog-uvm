# #667 wide automatic-bin regression, baseline RED

The new test uses a 512-bit `sample()` argument and `auto_bin_max = 1024`, so
the reported automatic-bin representation failure is tested independently of
class-property sampling. The expected result on the pinned main toolchain is a
compile-time error in both IEEE modes.

Slurm job `3106` confirmed the RED state in both editions. It used 1 CPU,
1 GiB RAM and a five-minute job limit. The pinned `cae035642e056644274a01e98d4422ce286685b4`
toolchain hashes are recorded in [`a3-667-red-3106.out.gz`](a3-667-red-3106.out.gz):
`iverilog` `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`,
`vvp` `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
Both `-g2017` and `-g2023` exited 1 with the reported “automatic bins for a
coverpoint wider than 64 bits are not represented” error. Logs and checksums
are preserved alongside the run script and source archive.
