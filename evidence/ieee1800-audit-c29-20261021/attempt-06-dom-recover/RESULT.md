# Clause 29 dominance result

Slurm job 3696 on DAN-DESKTOP completed with exit 0, requesting 1 CPU and 1 GiB. It used protected Icarus 13.0-devel source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; compiler SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.

Both `-g2017` and `-g2023` produced the expected output:

```text
REC 0 0
EDGE 1
DOM 0
```

`REC` confirms the level-sensitive clear recovers from unmatched time-zero input transitions. `EDGE 1` confirms the edge row fires in the clear-inactive control. In the second instance, the same rising edge requests 1 while asserted clear requests 0; output 0 confirms the level-sensitive row determines the result, as described in §§29.9–29.10.

The job record, raw scheduler output, compile logs, and both simulation outputs are preserved in [`raw-slurm-3696/`](raw-slurm-3696/). This supports IMPLEMENTED (tested subset) for §29.10; no gap issue was found.
