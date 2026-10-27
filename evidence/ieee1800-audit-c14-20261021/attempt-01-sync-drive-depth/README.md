# Clause 14 depth probes

Scope: IEEE 1800-2017 §§14.12–14.16.1 and corresponding IEEE 1800-2023 clauses. 2017 PDF pp.344–351; 2023 PDF pp.362–370 (printed pp.361–369). Both editions are tested with -g2017 and -g2023.

K1–K10 and G1/G2 exercise default/global clocking, clockvar sampling, virtual-interface event/drive behavior, output skew, cycle delay, selected and net clockvar targets, and global-clock resolution. N1–N6 are negative controls for duplicate defaults, scope, and prohibited clockvar writes.

The 2023 §14.11 wording changes “positive integer” to “non-negative integer” and “clocking events” to “clocking block events”; K9 uses ##3, so the expected result is unchanged. §14.13 changes “event associated with the clocking block name” to “clocking block event”; meaning is unchanged. §14.16 changes the syntax spelling for cycle_delay; K3's ##2 is legal in both.

Expected outcomes are in RESULT.md after Slurm execution. Sources are in input/; raw logs, return codes, scheduler data, and tool hashes are retained.
