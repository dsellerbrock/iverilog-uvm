# IEEE 1800 Clause 30 specify-path paired probe

This batch checks two-delay path rise/fall selection, `if`-conditioned paths, and default pulse rejection. It runs with and without `-gspecify` in both language editions. Only the `-gspecify` runs are used to classify IEEE behavior; Icarus ignoring specify blocks without that option is recorded as a tool-mode observation, not a standards gap.

## Standard basis

- §30.4.2 uses `=>` for a parallel input-to-output path. §30.5/Table 30-2 maps the first of two delays to 0→1 rise and the second to 1→0 fall, giving the 3-unit rise and 5-unit fall checks.
- §30.4.4 allows a state-dependent path whose delay applies only when its condition is true. Therefore `en=1` selects delay 2; `en=0` selects delay 7.
- §30.7 says “By default, pulses on a module path output are rejected.” The default reject and error limits equal the path delay, so the 2-unit pulse on a 3-unit rise path must not emerge.

These requirements agree in IEEE 1800-2017 and 1800-2023. Printed pages: 2017 §30.4.2 p. 841, §30.4.4 pp. 843–844, §30.5/Table 30-2 pp. 849–851, §30.7 pp. 854–855; 2023 §30.4.2 pp. 873–874, §30.4.4 pp. 875–876, §30.5/Table 30-2 pp. 881–883, §30.7 pp. 886–887.

Expected with `-gspecify`, in both editions:

```text
R1 0
R2 1
F1 1
F2 0
C1 0
C2 1
C3 1
C4 0
P1 0
```

Without `-gspecify`, transitions are zero-delay: R1/R2 become 1/1; F1/F2 0/0; C1/C2 1/1; C3/C4 0/0; P1 remains 0. Those values are recorded as a tool-mode observation only.

Probe: [`p30_specify.sv`](../../../../tests/1800_audit/c30/p30_specify.sv). Open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md); raw logs and results will be added after the Slurm run.
