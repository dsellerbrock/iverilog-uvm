# Issue #664 baseline

- Host: DAN-DESKTOP, Slurm job 2756 (`a3-664-red`), 1 CPU, 1 GiB, 5-minute limit.
- Source: `source/sv_class_method_noarg_string_concat.v` (sha256 recorded by the job).
- Compiler: c344-derived `iverilog-a3-m7-457-guard-c344-d884d145`, sha256 in `results/toolchains.sha256`.
- Commands: `iverilog -g2017 -s test ...` and `iverilog -g2023 -s test ...`; each had a 120-second process timeout.
- Result: both editions exit 1 with the string-concatenation operand type error on `child.convert2string`.
- The A2-pinned toolchain path guessed in the first script did not exist under `bin/iverilog` (exit 127); this is recorded as a path error, not a compiler result. The c344-derived toolchain is the valid reproducer evidence.

The exact candidate `iverilog -V` output is preserved as
[`branch-version.txt.gz`](results/branch-version.txt.gz); it was compressed
byte-for-byte after the result was recorded.
