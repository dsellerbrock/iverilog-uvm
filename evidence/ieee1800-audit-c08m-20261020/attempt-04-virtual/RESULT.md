# Attempt 04 result — clean paired-edition run

Slurm job 3499 completed on DAN-DESKTOP on 2026-10-20. Resources: 1 CPU,
1 GiB, 15-minute limit. Compiler: Icarus 13.0-devel from source `cc25756d1`;
`iverilog` SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`,
`vvp` SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
The complete TSV, diagnostics, elapsed time, peak RSS, hashes, and host data
are preserved in `results-3499.tar.gz`.

Both `-g2017` and `-g2023` compiled and ran the positive source with exact
expected output:

```text
V1 C C
V2 A2 C2
AB1 5
AB2 x
POLY Ether Token GPS
```

In both editions, the three invalid §8.21 controls were rejected. However,
`n08_21_missing_implementation.sv` compiled, constructed the non-virtual
subclass, called its inherited pure method, and printed `MISSING x`. The
standard states in §8.21 (2017 p.186; 2023 p.198): “all pure virtual methods
shall have overridden implementations in order to be extended by a
non-abstract class.” This remains pending lead classification and issue
filing. Dedupe search records are in
`../attempt-02-virtual/dedupe-open-closed.txt` and
`../attempt-03-virtual/dedupe-open-closed.txt`.

## Lead classification

The audit lead classified the missing inherited implementation as a distinct
§8.21 gap and filed [#846](https://github.com/dsellerbrock/iverilog-uvm/issues/846).
The lead confirmed the passing controls above and directed the matrix to record
§8.20 and §8.22 as tested subsets and §8.21 as PARTIAL. Total new audit issues
are now 111: §6 38, §8 2, §10 2, §11 8, §12 7, §15 2, §18 13, §19 1, §20 12,
§21 11, §23 5, §25 7, §26 1, §27 2.
