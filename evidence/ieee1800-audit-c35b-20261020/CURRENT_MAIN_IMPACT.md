# Probe-base relevance to current main

After fetching `origin`, current main was `10f3a0a25`.

Compared with the probe base `cc25756d187314742d347267c2a513b3e640a7fb`, the
production-source changes are confined to `vvp/vvp_cobject.cc`,
`vvp/vvp_cobject.h`, and `vvp/vvp_z3.cc`. They track active constraint counts
and select randomization tiers. There are no changes to `elaborate.cc`, the
parser, `vvp/vthread.cc`, or `vvp/vvp_dpi.cc`.

The §35.4 signature checks, imported open-array marshaling, and §35.8/§35.9
DPI call paths exercised by the paired-edition probes are therefore unchanged
in current main. This is a source-path comparison, not a rerun of the probes.
