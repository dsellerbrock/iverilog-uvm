# Clause 31 timing-check tranche 2 results

Slurm job 3688 on DAN-DESKTOP completed with exit code 0 (1 CPU, 1 GiB requested; 10-minute limit). Pinned Icarus 13.0-devel source is `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; compiler SHA-256 is `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`, and `vvp` SHA-256 is `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.

Both `-g2017 -gspecify` and `-g2023 -gspecify` compiled and ran with exit 0. Each produced exactly these seven reports and the matching notifier count:

```text
p31_tchk2.sv:14: Timing violation: $recovery check in p31_tchk2 at time 11
p31_tchk2.sv:15: Timing violation: $removal check in p31_tchk2 at time 21
p31_tchk2.sv:16: Timing violation: $period check in p31_tchk2 at time 36
p31_tchk2.sv:17: Timing violation: $skew check in p31_tchk2 at time 43
p31_tchk2.sv:18: Timing violation: $setuphold(setup) check in p31_tchk2 at time 50
p31_tchk2.sv:18: Timing violation: $setuphold(hold) check in p31_tchk2 at time 51
p31_tchk2.sv:19: Timing violation: $nochange check in p31_tchk2 at time 61
N 7 1
```

Stderr was empty for both editions. The observed times match the directly derived window rules in [`STANDARD.md`](STANDARD.md). Open+closed issue dedupe is recorded in [`DEDUPE.md`](DEDUPE.md); no matching issue was found for any of the six check kinds.

Full scheduler/compiler/run stdout and stderr are in [`raw-slurm-3688`](raw-slurm-3688/).
