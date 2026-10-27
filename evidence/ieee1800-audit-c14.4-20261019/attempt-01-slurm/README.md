# IEEE 1800 clause 14.4 probes

The source archive is clean `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`. The probe archive contains four focused §14.4 cases: `#1step` input / `#0` output skew, numeric input/output skew, output edge skew, and rejection of a nonconstant skew. Each positive case is compiled and run with `-g2017` and `-g2023`; the negative case must be rejected in both editions.

Slurm job requests 2 CPUs and 3 GiB. It builds the exact source archive and runs each test with a 120-second timeout. Raw results and matching checksums will be saved under `results/` after completion.

The local-only source archive (`input/source.tar.gz`, 227,069,756 bytes) is excluded from the PR; SHA-256: `fb22d029cef3f9fa504bd5831a991b64755bcc449e2a80d75258a90096ba363c`.
