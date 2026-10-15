# WP0 final-base correctness gates

Campaign-pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.
This one-time post-rebase gate base: `7f35ca38c86723ab40e6ebfe9fd77259827e23f9`.
Candidate: `1174ea06ac5e3a926b1fa1c1bd3449a396507272`.
UVM core: `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.

Slurm job 1150 rebuilt reference, stats-off, and stats-on installs from the
post-rebase base. Counter identity, `make check`, ivtest, FPGA install, and the
4,651-test JSON/VVP regression passed with zero new baseline failures. Job 1150
then failed because its UVM runner was invoked from the run directory; the
runner requires the candidate source root as its working directory. Follow-up
job 1181 passed that stage from the correct directory: 367 passed, 0 failed,
0 skipped, with real DPI. The
[corrected batch script](../full-gates.sbatch),
[isolated JSON runner](../run-json-isolated.py), and
[UVM follow-up script](uvm-followup.sbatch) are preserved here.
The combined result is `PASS`; see `aggregate-status.txt` and the
[`gate-evidence.tar.gz`](gate-evidence.tar.gz) bundle.
