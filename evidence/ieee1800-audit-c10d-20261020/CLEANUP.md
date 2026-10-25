# Slurm cleanup

After copying each job's logs and result files, removed only the corresponding run directories. `du -sb` recorded 21,506 bytes freed for job 3530, 12,679 bytes for job 3531, 34,350 bytes for job 3532, and 52,947 bytes for job 3533. The shared toolchain under `/home/dsell/toolchains` was not touched.
