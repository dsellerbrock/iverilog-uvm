# §16.9.4 global-clock sampled-value probes — attempt 15

This submission is a runner setup failure, not compiler evidence. Slurm job 3185 staged the clean `origin/main` snapshot `c31cbf1b52f1a39d5775f276e2340525a444a79e` and the probes, but exited before configuration because the script called `./configure` without first running the repository's required `autoconf` step. No probe compiled or ran. The next attempt adds that build-generation step in a fresh run directory.

- Job: 3185
- Resource request: 3 CPUs, 4 GiB, 30 minutes
- Failure: `timeout: failed to execute process: No such file or directory` for `./configure` (exit 127)
- Source archive SHA-256: `01af4f9a30d7def8f99a362ad830f4f3d23d8edc4b7164988dbedffc443fd41c`
- Probe source hashes are in `results/input.sha256`.
