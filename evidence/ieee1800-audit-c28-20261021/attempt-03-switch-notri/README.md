# IEEE 1800 Clause 28 isolated switch and strength probes

This batch removes the unsupported `trireg` declaration from the nmos/pmos/rnmos/tran case and separately probes the remaining resistive and CMOS strength rules. Both files are compiled and run under `-g2017` and `-g2023`.

## Standard basis

| Rule | IEEE 1800-2017 | IEEE 1800-2023 | Probe result expected |
| --- | --- | --- | --- |
| §28.7 Table 28-6; §28.13 | nmos passes the on-state data value and strength; pmos with control `1` is off; a supply input through nmos becomes strong | Same rules in Table 28-6 and §28.13 | `St1`, `HiZ` |
| §28.8; §28.13 | `tran` unconditionally passes signals in either direction with no propagation delay and no strength change except supply-to-strong | Same | `St0` |
| §28.14 Table 28-8 | Pull drive → weak drive | Same table mapping | `We1` for pullup through rnmos |
| §28.9 | CMOS is treated as the combination of a pmos and nmos sharing data input/output; with n-control `1` and p-control `0`, both are on and pass data `0` | Same | `St0` |
| §28.3.2 | Gate default strengths are strong1/strong0 | Same | `St0` for the cmos result |

For the reported text, IEEE 1800-2017 prints Table 28-6 on p. 807, §28.8 on pp. 807–808, §28.9 on p. 808, and §§28.13–28.14/Table 28-8 on p. 823. IEEE 1800-2023 prints Table 28-6 on p. 839, §28.8 on pp. 839–840, §28.9 on p. 840, and §§28.13–28.14/Table 28-8 on p. 855. The standard text says CMOS is “treated as the combination of a pmos switch and an nmos switch.”

Expected outputs in both editions:

```text
S St1 HiZ Pu1 St0
R We1 St0
```

Sources: [`p28_switch_notri.sv`](../../../../tests/1800_audit/c28/p28_switch_notri.sv), [`p28_strength_reduce.sv`](../../../../tests/1800_audit/c28/p28_strength_reduce.sv). Open+closed dedupe is in [`DEDUPE.md`](DEDUPE.md); the previous trireg compile rejection is documented in [attempt 02](../attempt-02-switch/RESULT.md).
