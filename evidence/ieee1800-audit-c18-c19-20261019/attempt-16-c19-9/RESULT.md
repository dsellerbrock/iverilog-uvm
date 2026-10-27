# Attempt 16 — Clause 19.9 probe

- Slurm job: 3002 on DAN-DESKTOP; `GATE_RESULT=PASS`.
- Standards: IEEE 1800-2017 §19.9 p. 584; IEEE 1800-2023 §19.9 p. 612.
- Toolchain: `/home/dsell/toolchains/iverilog-a3-main-82023726-679`.
- `iverilog` SHA-256: `17661deebeaf8180f5761c82d1eeb31f30b5605739c724cb82dc4a04975a8256`.
- `vvp` SHA-256: `911cd2ba4a1f1a62afeb6b9463ee18a3aab338e09cb5eb89c8b1a73b0b4138cc`.
- Input archive SHA-256: `7040106a0695a6f8f6b600ee2ca57b4aeb32957a8bcbdb190e504518481d75ed`.
- Submitted script SHA-256: `d825dde025c2dd7c7c3895bcb1eb67e4901dd1908f104bc392793edc497694c9`.
- Raw results bundle SHA-256: `130a435483cc919165a27b5e5ff37f7b1c63fb06e8ef130608b3453637f10e8c` (`results-3002.tar.gz`).

The positive probe compiled and ran in both editions. It asserted global
coverage values of 0%, 50%, and 100%. The non-string filename compile failed
in both editions with `argument 1 of $set_coverage_db_name must be a string`.
The positive runs emitted warnings that the coverage-database backend is
unavailable for both `$set_coverage_db_name` and `$load_coverage_db`. This
confirms `$get_coverage` behavior and compile-time argument checking, but not
database save/load support. The lead classifies §19.9 PARTIAL; the missing
database persistence behavior is tracked in [issue #688](https://github.com/dsellerbrock/iverilog-uvm/issues/688).
