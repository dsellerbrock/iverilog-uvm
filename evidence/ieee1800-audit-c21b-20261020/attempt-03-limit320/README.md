# §21.7.3.4 320-byte boundary confirmation

This reruns the same probe with `$dumpportslimit(320, "lim.evcd")`, as requested by the audit lead. It is a boundary confirmation, not a gap test. Both editions passed compile/run with exit 0 and emitted byte-identical files. The limited output is 411 bytes total: 337 precede the comment (17 bytes past the threshold), followed by the required marker and close record. It contains the initial value and seven subsequent value records, then no more value records. The 1,097-byte unlimited control file continues through time 52000.

The Slurm log, exact source/tool hashes, and raw outputs are stored with the §26.7 batch in [attempt-01-std](../../ieee1800-audit-c26a-20261020/attempt-01-std/remote-3555/). The input copy is [here](input/p21_evcd_limit.sv).
