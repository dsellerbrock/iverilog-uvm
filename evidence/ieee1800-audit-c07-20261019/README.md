# Clause 7 audit probe progress — 2026-10-19

Probe source lives in `../../tests/1800_audit/c07/`; each current-main run used the immutable toolchain from `attempt-08-c07-current-main/README.md`.

| Area | Evidence | Result |
| --- | --- | --- |
| Memory, whole-array assignment, packed-array/vector assignment, array arguments, tested associative-array methods/literals | [Attempt 08](attempt-08-c07-current-main/README.md) | Passed in 2017 and 2023 modes |
| Tagged-union inactive-member access | [Attempt 08](attempt-08-c07-current-main/README.md) | Required run-time error reported in both modes |
| Missing 2-state associative-array read | [Attempt 11](attempt-11-invalid-associative-index-rerun/README.md) | Returns zero without allocation and warns in both modes |
| Invalid X/Z wildcard associative-array write | [Attempt 11](attempt-11-invalid-associative-index-rerun/README.md) | Incorrectly allocates and does not warn in both modes; gap awaits lead issue filing |
| Class-property dynamic-array slice assignment | [Attempt 12](attempt-12-class-property-slice-current-main/README.md) | Rejected in both editions by current main; tracked as #671 |

Attempts 09 and 10 are preserved as staging/probe corrections, not simulator evidence. After checksum verification, remote run roots 08–11 were removed, freeing 48,008,150 bytes (45.8 MiB).
The separate current-main §7.6 probe root 12 was also removed after verification (4,995 bytes). Total A3 Clause 7 audit run data freed: 48,013,145 bytes (45.8 MiB).
