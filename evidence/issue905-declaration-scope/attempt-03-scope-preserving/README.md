# Slurm job 3847 — failed scope-preserving attempt

Commit `4d5378a232cc27ad04d011a257eebad04ffbaa2f` passed the build, `make check`, install, and smoke, but T0/T1 failed. Several compiles aborted in `dll_target::find_signal` because temporarily removing formal NetNets while leaving parser placeholders let identifier lookup create a replacement NetNet; restoring the original then left expressions pointing at a signal with no target. The class receiver test also lost the synthetic `@` handle.

This attempt was superseded by commit `7b7f4d10`, which removes/restores placeholders together with formal signals and preserves the synthetic receiver. Complete job output and hashes are in `raw-slurm-3847/`.

The staged source archive (SHA-256 `e534c8987c8572f50e685c1e2699328df78dafa0617b88d1b0eeab89353a1ab4`) was removed after recording its hash; it duplicated committed source at `4d5378a232cc27ad04d011a257eebad04ffbaa2f`. The run script and complete raw logs remain here.
