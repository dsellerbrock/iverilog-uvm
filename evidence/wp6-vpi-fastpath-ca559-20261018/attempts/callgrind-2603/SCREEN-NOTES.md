# Combined 18-workload screen

Pinned base: `ca559fd97b19bd6a56cc10f0faf8583b4077975f`.
Combined source patch SHA-256: `61047cc299d43f5b76a31ddc91622e475f0ef57c8ef0d9cc326ab4445d26ca35`.

The `core` and `vectors` groups completed normally. Group `mixed` produced all
six Callgrind profiles and summaries, but its wrapper returned 1 because the
FST workload's process exited with signal 11 at thread shutdown. An isolated
Callgrind retry (job 2611) produced the same shutdown failure on the reference
binary. The plain-runtime oracle (job 2612) then ran three interleaved pairs on
one pinned CPU; reference and candidate stdout plus FST files compared byte for
byte on every pair. The two Callgrind summaries are 14,172,749,439 and
14,194,733,385 instructions (+0.155114%). The raw job provenance file contains
a stale hard-coded percentage; this value is recomputed from those preserved
profiles.

Across the 18 rows, `vpi_callbacks` improves 14.052199%. The largest increase
is `waveform_vcd` at 0.303236%, below the 2% screen limit. All 18 output checks
passed. See `instruction-counts.csv` and the per-group archives for raw counts
and profile data.
