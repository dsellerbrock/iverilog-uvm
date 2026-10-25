# Clause 29 isolated UDP probe result

Slurm job 3693 on DAN-DESKTOP completed with exit 0, requesting 1 CPU and 1 GiB. It used Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; the compiler SHA-256 was `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`, and `vvp` SHA-256 was `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.

Both `-g2017` and `-g2023` produced the expected `p29_more.sv` output:

```text
I1 x 1
I2 1 1
D1 0 0
DOM 0
```

This verifies the tested unnamed UDP instance, two-value delay, and the mixed table's tested transitions. The dominance case was rerun with a direct edge-only control in [attempt 04](../attempt-04-dominance-control/RESULT.md).

The scalar-port instance array failed to compile in both editions with:

```text
sorry: UDPs with a range (ua [1:0]) are not supported.
```

The three-delay case was rejected in both editions with `UDPs take at most two delay arguments`, as required by §29.8. Full compile and runtime logs, source hashes, and scheduler state are preserved in [`raw-slurm-3693/`](raw-slurm-3693/). No existing issue matched the searches recorded in the parent attempt's [`DEDUPE.md`](../attempt-02-udp-more/DEDUPE.md). Lead classification is pending.
