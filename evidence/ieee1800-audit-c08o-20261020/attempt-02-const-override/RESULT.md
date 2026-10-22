# IEEE 1800 §§8.19–8.20 paired-edition probe (Slurm job 3502)

Host: DAN-DESKTOP. Icarus 13.0-devel source `cc25756d1`; compiler SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; vvp SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`. Ran all cases with `-g2017` and `-g2023`; each test has a 30-second timeout. Raw logs and result table are in `results-3502.tar.gz` (SHA256 `89f19cac683f62c64f243e268bd0aa7c287b131fb1cc2ce613200ad83b182348`).

## Results

| Probe | IEEE expectation | Icarus result in both editions |
|---|---|---|
| `p08_19_20.sv` standard `Jumbo_Packet`, instance constructor constants, covariant virtual return | Compile/run; `K1 9216 5`, `K2 3 4`, `V6 ok` | Passed these controls |
| `V7`: base default 1, override default 2, call through base handle | Earlier lead instruction expected `V7 2`; this expectation needs standards confirmation | Prints `V7 1` in both editions |
| global constant reassignment | Reject | Rejected with §8.19 diagnostic |
| instance constant assignment outside constructor | Reject | Rejected with constant-property diagnostic |
| static instance constant | Reject | Rejected |
| external instance-constant write | Reject | Rejected |
| double assignment in constructor (record-only) | Record behavior | Rejected at compile time with §8.19 diagnostic |
| override renames argument | Reject | Accepted silently |
| override changes argument type | Reject | Accepted silently |
| override changes direction | Reject | Accepted silently |
| override changes return type | Reject | Accepted silently |
| override changes default presence | Reject | Accepted silently |

The compiler accepted all five malformed virtual overrides in both editions. The lead confirmed V7 printing 1 is not a gap: neither edition specifies which default expression applies when the call uses a base handle. The five accepted signature mismatches are one §8.20 gap; the lead filed [#848](https://github.com/dsellerbrock/iverilog-uvm/issues/848).

## Open+closed dedupe

Searched all issue states for: `virtual override`, `override signature`, `method signature`, `override argument`, `override default`, `covariant return`, `8.20`, `8.19`, `const class property`. Search output and reviewed-hit summaries are in `dedupe-open-closed.txt` and `dedupe-reviewed-hits.txt`. #455 concerns override specifiers; #847 concerns out-of-block prototype matching; neither duplicates the signature checks here. Other hits are unrelated (see reviewed list).

Standards source check: IEEE 1800-2017 §8.19 (p.183) and §8.20 (p.184); IEEE 1800-2023 §§8.19–8.20. Both editions state the same key override constraints: matching argument types/names/qualifiers/directions, matching or covariant return type, and matching default-argument presence while allowing different default expressions. The standards do not specify which default value is used at a call site; the lead classified the observed `V7 1` as non-gap.

Issue count after #848: total 113; §6 38, §8 4, §10 2, §11 8, §12 7, §15 2, §18 13, §19 1, §20 12, §21 11, §23 5, §25 7, §26 1, §27 2.
