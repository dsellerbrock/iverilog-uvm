# Slurm job 3003 setup failure

Pinned current-main commit: `cae035642e056644274a01e98d4422ce286685b4`. Job 3003 stopped before cloning/building because the staged run directory was missing `input/source.commit`. It collected no samples and is not measurement evidence. The original Slurm output and exit code are preserved here; job 3004 reruns the same pinned profile in a fresh directory with the missing manifest staged.
