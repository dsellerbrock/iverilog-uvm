# §8.23–§8.25.1 probe result

Slurm job 3500 completed on DAN-DESKTOP on 2026-10-20. Resources: 1 CPU,
1 GiB, 15-minute limit. Compiler: Icarus 13.0-devel at source `cc25756d1`;
`iverilog` SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`,
`vvp` SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
Raw TSV, diagnostics, timing/RSS, hashes, and host details are in
`results-3500.tar.gz`.

The positive source compiled and ran in both editions with exact output:

```text
SC1 2
SC2 1
SC3 7
OB1 2 9
OB2 4
PC1 2 10
```

The §8.25.1 control `int x = C::p;` outside the parameterized class was
rejected in both editions with the expected explicit-specialization diagnostic.
The §8.24 negative out-of-block definition with an extra argument compiled
without a diagnostic in both editions. The standard requires the out-of-block
declaration to “match the prototype declaration exactly” (§8.24; 2017 p.189,
2023 p.202). This is a candidate gap pending lead classification. No issue has
been filed yet; the open-and-closed dedupe is in
`dedupe-open-closed.txt`.

## Lead classification

The audit lead classified the mismatch as a distinct §8.24 gap and filed
[#847](https://github.com/dsellerbrock/iverilog-uvm/issues/847). The lead
confirmed the §8.23 and §8.25.1 controls pass, along with matching §8.24
function/task bodies and the out-of-block return-type example. The matrix now
records §8.23 and §§8.25–8.25.1 as IMPLEMENTED (tested subset) and §8.24 as
PARTIAL. Total audit issues: 112 — §6 38, §8 3, §10 2, §11 8, §12 7, §15 2,
§18 13, §19 1, §20 12, §21 11, §23 5, §25 7, §26 1, §27 2.
