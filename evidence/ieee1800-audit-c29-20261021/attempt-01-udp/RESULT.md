# IEEE 1800 Clause 29 UDP paired-probe results

## Environment

- Slurm job 3663 on DAN-DESKTOP, 1 CPU and 1 GiB; `JobState=COMPLETED`, `ExitCode=0:0`, `RunTime=00:00:01`.
- Protected Icarus 13.0-devel toolchain source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; executable and library hashes are in [`remote-3663/a3-c29-udp-3663.out`](remote-3663/a3-c29-udp-3663.out).
- `p29_udp.sv` compiled and ran with exit code 0 in both editions. Raw logs are under [`remote-3663/logs/`](remote-3663/logs/).

## Results

| Edition | Output |
| --- | --- |
| `-g2017` | `L0 1`, `M1 1`, `M2 0`, `M3 1`, `M4 x`, `M5 0`, `L1 0`, `L2 0`, `F1 1`, `F2 1`, `F3 0`, `F4 x` |
| `-g2023` | Identical |

The combinational table's unspecified case returned x, and a z input matched x. The sequential latch's initial value and no-change row held the expected state; the edge-sensitive UDP's transitions and unspecified transition produced the expected values. No mismatch was observed in this tested subset.

## Standard basis and dedupe

The matching requirements are in §29.3.4–§29.7: unspecified table cases return x; z inputs are treated as x; combinational UDPs return x for unmatched cases; level-sensitive and edge-sensitive tables use a current-state field and `-` for no change; and §29.7 permits a sequential UDP initial output value. The two PDFs place the sequential UDP initialization rule in §29.7, not §29.4. See [`README.md`](README.md) for citations/pages. Open+closed searches `UDP`, `primitive table`, `edge-sensitive UDP`, and `29.` found no Clause 29 issue; see [`DEDUPE.md`](DEDUPE.md).

After copying the logs and results locally, only this run's remote build directory was removed; inputs and logs remain in the run directory.
