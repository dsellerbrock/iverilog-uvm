# #671 regression before the fix

The paired `-g2017` and `-g2023` class-property regression both fail to
elaborate against the pinned main toolchain, with the expected unsupported
dynamic-array slice diagnostic at each property assignment.

- Host: DAN-DESKTOP, Slurm job 3145, one CPU and 1 GiB RAM.
- Toolchain: pinned main build from `cae035642e056644274a01e98d4422ce286685b4`.
- `iverilog` SHA-256: `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`.
- `vvp` SHA-256: `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
- Source SHA-256: `888e6563ebf398fa2c3a1efc9826c03989f13806becc56e9624649659e4c85e3`.
- Commands: `iverilog -g2017 -s test ...` and `iverilog -g2023 -s test ...`, each under `run_with_timeout.py 120`.
- Both commands exit 2 and report `dynamic-array slice r-values are not yet supported as fixed-size unpacked-array expressions` for both slice assignments.

Raw compiler and Slurm output is preserved in `raw-slurm-3145/`.
