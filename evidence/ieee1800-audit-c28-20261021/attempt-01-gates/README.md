# IEEE 1800 Clause 28 paired gate and strength probe

This probe checks two-input logic tables, `bufif1` with an unknown control, default gate and pull strengths, wired-net resolution, `%v` formatting, and distinct rise/fall delays. The same source is compiled and run with `-g2017` and `-g2023`.

## Standard basis

- IEEE 1800-2017 and 1800-2023 §28.4, Table 28-3: `and(1, x)` resolves to `x`, while `and(0, x)` resolves to `0`. With two delays, the first is the rise delay and the second the fall delay. The test uses `buf #(3, 5)` to distinguish them.
- §28.5, Table 28-4 defines `buf` as passing the input value. §28.6, Table 28-5 maps `bufif1` data `1` and control `x` to `H`; the text defines `H` as “a result that has a value 1 or z.”
- §28.3.2 gives `strong1`/`strong0` as the default gate strengths. §28.10 gives `pullup` pull strength by default. §21.2.1.5 (2017) and §21.2.1.4 (2023) define `%v`; their tables use `St` for strong, `Pu` for pull, and `H` for 1-or-Z. Therefore the expected strength fields are `StH` and `Pu1`.
- §6.6.3, Tables 6-3 and 6-4 define the `wand`/`wor` truth tables for equal-strength drivers. §28.12.2 says equal-strength conflicting drivers on an ordinary net resolve to `x`; §28.12.4 defines wired resolution as AND/OR logic.
- §28.16, Table 28-9: a two-delay gate uses d1 for transitions to `1` and d2 for transitions to `0`. Input rise at t10 schedules output rise for t13; input fall at t21 schedules output fall for t26.

The extracted 2017 pages are §§28.3.2–28.6 pp. 799, 803–806; §28.10 p. 809; §28.12 pp. 811, 821; and §28.16 p. 824. The corresponding 2023 pages are pp. 831, 835–838, 841, 843, 853, and 856. §6.6.3 is pp. 87–88 in 2017 and 92–93 in 2023.

## Expected output

```text
G x 0 StH 0 1 x Pu1
D1 12 0
D2 14 1
D3 25 1
D4 27 0
```

Probe source: [`p28_gates.sv`](../../../../tests/1800_audit/c28/p28_gates.sv). Open+closed issue searches and dispositions: [`DEDUPE.md`](DEDUPE.md). Run logs and result are recorded in this directory after the paired Slurm run.
