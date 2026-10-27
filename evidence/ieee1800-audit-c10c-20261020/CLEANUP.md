# Slurm cleanup

After copying job 3527's logs and result files into the evidence directory, removed only its run directory `/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c10-patterns-20261020-01`. `du -sb` recorded 13,442 bytes freed. After copying job 3528's logs and result files, removed only `/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c10-default-20261020-02`; `du -sb` recorded 44,588 bytes freed. The shared toolchain under `/home/dsell/toolchains` was not touched.
