# §10.11 net aliasing

Slurm job 3534 ran the §10.11 probes with Icarus 13.0-devel (`cc25756d1`) in both `-g2017` and `-g2023`; each compile/run had a 30-second timeout (1 CPU / 1 GiB).

The byte-swap and bidirectional-driver positive compiled and ran in both editions, printing `AL 44332211 1`. The variable alias and width-mismatch negatives were rejected in both editions. The self-alias and reverse duplicate-pair negatives unexpectedly compiled and ran successfully in both editions, contrary to §10.11. Both required checks are stated explicitly in the cited clause.

Raw compiler/runtime results and the complete Slurm transcript are under `results-3534/results/` and `slurm-3534.out`. Open and closed issue searches for `alias`, `net alias`, and `10.11` are in `dedupe-results.md`; no existing issue covers self/duplicate net-alias rejection. Sources and hashes are under `input/`.
