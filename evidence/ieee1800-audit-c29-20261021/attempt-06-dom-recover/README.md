# IEEE 1800 Clause 29 level-dominance probe

The paired probe follows the reviewed design from the 1800-audit lead. It recovers state after time-zero unmatched transitions (`REC 0 0`), verifies the clean edge-only control (`EDGE 1`), and then checks the conflicting edge and level rows (`DOM 0`). The §29.5, §29.6, §29.9 and §29.10 basis is recorded in [`STANDARD.md`](STANDARD.md).

Source: [`p29_dom.sv`](../../../tests/1800_audit/c29/p29_dom.sv). Both `-g2017` and `-g2023` run with the protected toolchain, 1 CPU, 1 GiB, and 30-second per-command timeouts. Slurm job 3696 passed; raw logs are in [`raw-slurm-3696/`](raw-slurm-3696/).
