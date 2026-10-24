# §7.10 empty-queue pop default types

The single source compares `pop_front()` and `pop_back()` against an invalid read of the same empty queue for `int`, `bit`, `logic`, `integer`, `real`, `string`, and class handles. IEEE 1800-2017 §7.10.2.4/.5 requires empty pops to return the same value as a nonexistent element; its Table 7-1 is §7.4.6. IEEE 1800-2023 renumbers that table to §7.4.5.

Expected data output is `input/expected.txt`; all warnings are optional and captured verbatim if emitted. Each edition uses a 30-second timeout per compile and run. Slurm resources: 1 CPU, 1 GiB, 10 minutes.

## Archive integrity

- `results-3511.tar.gz`: 3098 bytes; SHA-256 `a024f633b453ecb41cdc17ff46cab872208fd150c6478b0fba56a705f9fd9f0e`.
