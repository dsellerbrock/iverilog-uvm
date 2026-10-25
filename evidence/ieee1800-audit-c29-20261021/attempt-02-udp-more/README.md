# IEEE 1800 Clause 29 UDP follow-up probe

This attempt covers the remaining §29.8–§29.10 behaviors in IEEE 1800-2017 and 1800-2023. Requirements and pinpoint citations are recorded in [`input/STANDARD.md`](input/STANDARD.md); open+closed issue searches are in [`DEDUPE.md`](DEDUPE.md).

## Inputs

- Positive combined attempt: [`input/p29_more.sv`](input/p29_more.sv)
- Negative: [`input/n29_delay3.sv`](input/n29_delay3.sv)
- Expected positive output: [`expected.txt`](expected.txt)
- Slurm script: [`run.sbatch`](run.sbatch)

The tracked source tree was dirty at commit `27f53df24`; the new probe files were staged separately under `/home/dsell/slurm-runs/iverilog-uvm/A3/c29-udp-more-20261021-01/`. The run uses protected Icarus 13.0-devel toolchain source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.

## First combined run

- Slurm job 3692 on DAN-DESKTOP, 1 CPU, 1 GiB, completed in 1 second with exit 1.
- Both `-g2017` and `-g2023` rejected the combined source at the UDP instance-array declaration (`sorry: UDPs with a range (ua [1:0]) are not supported`). The combined compile prevented the mixed-sensitivity, dominance, and three-delay cases from being reached.
- Raw scheduler output and both edition diagnostics are in [`raw-slurm-3692/`](raw-slurm-3692/). The array case and remaining cases were split into the isolated follow-up at `attempt-03-udp-isolated`.
