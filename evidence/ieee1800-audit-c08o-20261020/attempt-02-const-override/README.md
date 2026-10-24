# IEEE 1800 §§8.19–8.20 retry: constant properties and virtual override matching

Retry of attempt 01. The positive probe in attempt 01 used `small`, a reserved strength keyword, so its syntax errors were probe-only. This attempt renames that variable to `small_pkt`; all semantic probes are otherwise unchanged.

Runs the standard `Jumbo_Packet` positive control, legal constructor initialization, covariant virtual return, differing-but-present override defaults, four invalid constant writes, five malformed override signatures, and the record-only double constructor assignment under both `-g2017` and `-g2023`.
