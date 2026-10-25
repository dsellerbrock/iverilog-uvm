# IEEE 1800 §24.3.1 program scheduling probe

## Standard basis

IEEE 1800-2017 and 1800-2023 §24.3.1 require program-block initial
procedures and event-sensitive statements to execute in the Reactive region.
They specify that program nonblocking updates execute in Re-NBA. The tested
four region-ordering requirements are common to both editions.

## Probe and result

- Existing probe: [`m6_reactive_region_test.sv`](../../../tests/m6_reactive_region_test.sv). It checks that a program samples design state after the same-edge NBA, program `#0` precedes Re-NBA, program NBA changes are visible in the same slot, and design Active-region reactions precede the program's next `#0` continuation.
- Slurm job 3603 used current-main toolchain commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, one CPU, 1 GiB, and a 5-minute allocation. The probe compiled and ran with both `-g2017` and `-g2023`. Both editions exited 0 and printed `PASS`; each test command had a 30-second timeout. This also confirms both edition flags are available in this toolchain.
- Source SHA-256: `f50ab40d6483f47aa71cb0dc2b2b266e48479f964e53dfcf2c509347f3162474`.
- Raw stdout, stderr, and Slurm output are retained in [`remote-3603/`](remote-3603/).

## Lead status

No gap was observed in this tested subset, so no issue was proposed. The matrix remains lead-pending until the audit lead classifies it.
