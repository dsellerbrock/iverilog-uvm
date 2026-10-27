# Attempt 09 — invalid-index probe staging error

Slurm job 3249 did not exercise the simulator. The probe archive contained the test at its root, but the script expected `tests/1800_audit/c07/p07_08_invalid_assoc_index.sv`; both compiler invocations therefore returned 1 with “No such file or directory.” The exact source, script, compiler logs, result archive, Slurm log, and SHA-256 manifest are preserved here. This attempt is not conformance evidence. The remote run root was removed after transfer and checksum verification.
