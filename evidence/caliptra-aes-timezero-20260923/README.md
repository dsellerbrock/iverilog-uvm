# Diagnostic AES time-zero reducer (2026-09-23)

The diagnostic Caliptra run with native vectors and the reset-timing copy
reached 100,000,000 scheduler events at **0 ps**. Its unbuffered progress trace
at `../caliptra-icarus-l0-startup-progress-20260923/progress.log` moves past
the finite DCCM, ICCM, and MBOX preloads, then repeatedly visits
`aes_pkg::aes_mul2` and `rcon_update` in both the AES and CSRNG instances.
This run has no firmware execution or L0 pass marker.

`automatic_local.sv` reduces the observed interaction. The package function
matches the pinned Caliptra `aes_mul2` bit-select writes
(`caliptra-rtl/src/aes/rtl/aes_pkg.sv:596`); each cell calls it from
`always_comb`. One cell settles, but two cells with different inputs keep
reactivating each other. `WHOLE_ASSIGN` computes the same value with one
whole-vector write and both cells settle.

| Edition | Variant | Compile | VVP result |
| --- | --- | ---: | --- |
| 2017 | one cell, bit writes | 0 | `REDUCER PASSED` at 1 ns |
| 2017 | two cells, bit writes | 0 | watchdog at 10,000 events, 0 ps; no pass marker |
| 2017 | two cells, whole write | 0 | `REDUCER PASSED` at 1 ns |
| 2023 | one cell, bit writes | 0 | `REDUCER PASSED` at 1 ns |
| 2023 | two cells, bit writes | 0 | watchdog at 10,000 events, 0 ps; no pass marker |
| 2023 | two cells, whole write | 0 | `REDUCER PASSED` at 1 ns |

Reproduce one RED, then repeat with `-g2023`:

```sh
local-install/bin/iverilog -g2017 -s automatic_local -D PAIR \
  -o /tmp/aes_timezero.vvp evidence/caliptra-aes-timezero-20260923/automatic_local.sv
IVL_SAME_TIME_LIMIT=10000 local-install/bin/vvp -n /tmp/aes_timezero.vvp
```

Omit `-D PAIR` for the one-cell control or add `-D WHOLE_ASSIGN` for the
two-cell whole-write control. The watchdog exits zero, so the absence of the
pass marker and the watchdog diagnostic determine the RED result.

Generated VVP for the bit-write pair includes the package function-local
`out` in **both** cells' `anyedge` sensitivity lists; e.g. in the 2017
image, `v0x78bd080020_0` appears in events `E_0x78bd0c0000/2` and
`E_0x78bd0c00d8/2`. The whole-write pair excludes `out` from both lists.
The full Caliptra image likewise includes its shared `aes_mul2.out`
(`v0x7804aa2560_0`) in sensitivity events `E_0x782358e088/3` and
`E_0x7823e2b780/3` for the two `rcon_update` instances, generated from
`caliptra-rtl/src/aes/rtl/aes_key_expand.sv:105`.

This identifies an implicit-sensitivity elaboration defect for function-local
partial writes as the likely compiler owner. No compiler fix is included here.
The full run uses `-gcommercial-unsafe` and a reset-timing testbench copy;
it is diagnostic nonstandard compatibility evidence, not an IEEE or released
Caliptra L0 pass.
