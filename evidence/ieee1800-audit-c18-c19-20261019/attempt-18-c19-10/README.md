# Clause 19.10 option-structure probe

Following the audit lead's scoped probe, this run tests post-construction
procedural reads and writes of `option.weight` and `option.at_least` through
covergroup, coverpoint, and cross instances; writes coverpoint `goal` and
`comment`; and rejects a nonexistent member. It runs the same checks in
`-g2017` and `-g2023`.

The normative structure layouts are in IEEE 1800-2017 §19.10 pp. 585–586 and
IEEE 1800-2023 §19.10 pp. 613–614. Existing §19.7 probes separately cover
2023-only `cross_retain_auto_bins` and `real_interval` members.

Attempt 17 was canceled while pending and produced no result; see its
`CANCELLED.md`. Slurm job 3008 runs one CPU with a 1 GiB memory limit. The
input archive SHA-256 is
`2255741bd3edb3cb627a584ea94718486083c9e61e61b87911591db16d4daf0a`; the
submitted script SHA-256 is
`6fef64254ac9774456cb661c25c5b40215c8b90c868185facd6bbb72c2e4296e`. Raw
commands, toolchain hashes, timing, and logs will be recorded in `RESULT.md`.
