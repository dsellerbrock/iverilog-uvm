# IEEE 1800 Clause 28 switch-level and charge-decay probes

This paired-edition batch exercises nonresistive MOS switches, a resistive MOS strength reduction, an always-on bidirectional `tran`, `trireg` charge storage, and charge decay. It runs [`p28_switch.sv`](../../../../tests/1800_audit/c28/p28_switch.sv) and [`p28_trireg_decay.sv`](../../../../tests/1800_audit/c28/p28_trireg_decay.sv) under `-g2017` and `-g2023`.

## Standard basis

- §28.7 Table 28-6: an nmos with data `1` and control `1` outputs `1`; pmos with data `1` and control `1` outputs `z`.
- §28.8: `tran` has two bidirectional terminals, unconditionally conducts signals both ways, and has no propagation delay.
- §28.13: nmos and tran preserve signal strength except supply becomes strong. §28.14 Table 28-8 reduces supply strength through rnmos to pull strength. Thus the first output line expects `St1 HiZ Pu1 St0`.
- §28.15.2: a charged trireg uses its declared charge strength; the test checks medium strength after the `bufif1` driver turns off.
- §28.16.2: charge decay starts when drivers turn off, and elapsed decay time changes a stored `1` or `0` to `x`. The small-charge net is released at t5 with a 10-unit decay time; therefore it is `Sm1` at t14 and x at t16.

These requirements match in IEEE 1800-2017 and 1800-2023. Printed pages: 2017 §28.7 Table 28-6 p. 807, §28.8 pp. 807–808, §§28.13–28.15 p. 823, §28.16.2 p. 826; 2023 §28.7 Table 28-6 p. 839, §28.8 pp. 839–840, §§28.13–28.15 p. 855, §28.16.2 p. 858.

Expected outputs in both editions:

```text
S St1 HiZ Pu1 St0
C1 Me1
T14 14 Sm1
T16 16 x
```

Open+closed issue searches are recorded in [`DEDUPE.md`](DEDUPE.md); raw logs and results are recorded here after the Slurm run.
