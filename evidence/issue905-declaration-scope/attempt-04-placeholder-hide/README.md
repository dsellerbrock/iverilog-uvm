# Slurm validation and corrected implementation

Commit `7b7f4d10f33494a50e3fddecdb2fa0712e40dbc8` hides formal NetNets and parser placeholders together, while keeping the synthetic class receiver visible.

Job 3851 used a source archive verified against SHA-256 `725bab46b19641bf8d9e836e1c170895278a44d77e92c59915764fd16bbad1e5`. Build, `make check`, install, smoke, and all four T0 legacy/JSON reproducer cases passed. T1 legacy passed 17/20: the three failures were wrapper include paths missing `-Iivltests`. Selected JSON passed the four #905 cases; the receiver pair also needed the standard `PASSED` output marker, added in `a139d2eb`.

Raw Slurm logs and hashes are in `raw-slurm-3851/`. The 3850 extraction failure is documented under `staging-failure-3850/`; it ran no tests.
