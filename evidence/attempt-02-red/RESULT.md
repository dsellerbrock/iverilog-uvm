# Issue #680 TDD baseline

- Base: current `main` at `82023726be90ab269d6e0ef5e755ebb69e6f648c`.
- Host: DAN-DESKTOP, Slurm job 2881; 1 CPU, 2 GiB, 5 minute limit.
- Compiler: `/home/dsell/toolchains/iverilog-uvm-4bfe7d04/bin/iverilog`, SHA-256 `46c3d1ab2626e7ccc4ac26be490aa8be64f78a62d2370d68efcf959bbdcbd372`.
- Reproducer SHA-256: `d4229ae0da3943cc3633fd3789f49911966a49ba6d327fbea9072ed28a8abc5f`.

The newly registered test compiles with `-g2017` and `-g2023` and calls the imported package function from an inline `randomize() with` clause using a module-scope string. Both editions failed as expected with `constraint ... could not be translated and the randomize call cannot be compiled` (compiler exit 2). The baseline harness recorded `BASELINE_EXPECTED_RED=PASS`; raw per-edition logs and Slurm stdout are in this directory.
