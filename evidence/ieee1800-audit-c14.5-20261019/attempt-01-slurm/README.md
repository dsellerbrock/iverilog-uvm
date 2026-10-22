# IEEE 1800 clause 14.5 probes

The clean source archive is `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`. Four focused cases cover hierarchical clocking references, bit/part-select expressions, concatenation expressions, and rejection of an illegal output expression. Positive cases are compiled and run with `-g2017` and `-g2023`; the negative case must fail compilation in both editions.

Slurm requested 2 CPUs and 3 GiB. Each compile/run has a 120-second timeout. The probe archive contains only the four §14.5 sources. Raw results and logs are saved under `results/` and `logs/`; `RAW-SHA256SUMS` and `input/SHA256SUMS` verify the saved files.

The local-only source archive (`input/source.tar.gz`, 227,069,756 bytes) is excluded from the PR; SHA-256: `fb22d029cef3f9fa504bd5831a991b64755bcc449e2a80d75258a90096ba363c`.
