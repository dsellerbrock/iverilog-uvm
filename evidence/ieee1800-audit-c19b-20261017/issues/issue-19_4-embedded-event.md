Clause: IEEE 1800-2017 §19.4 (p. 557) / IEEE 1800-2023 §19.4 (p. 579).

Requirement: §19.4’s embedded-covergroup example states that data members `m_x` and `m_y` are sampled on every change of member `m_z`.

Probe: `evidence/ieee1800-audit-c19b-20261017/attempt-03/input/p19_04_embedded_event.sv`, compiled/run with `-g2017` and `-g2023` using Icarus 13.0 devel at source `9b5fad2af` (same compiler SHA-256 in both editions: `6cd9749cb1e981820f64fdc737ae458bf6c46e3fcad8927afaf92649ee9a3288`). Raw output: `evidence/ieee1800-audit-c19b-20261017/attempt-03/results/combined.txt`.

Observed: elaboration warns `Failed to evaluate event expression 'm_z' (compile-progress: event skipped)`. The first change records 50% coverage; the second change does not record the other bin.

Expected: each change of `m_z` samples the embedded covergroup.
