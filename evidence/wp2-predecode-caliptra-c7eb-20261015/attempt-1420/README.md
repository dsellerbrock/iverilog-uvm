# Caliptra predecode instruction screen — job 1420

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

The reference and candidate use the same Caliptra test, generated firmware and
native-vector inputs, and the same fixed mcycle window (100–200). Candidate
patches are descriptor predecode (v1) plus `setarray` result construction
(v2); both are applied to the pinned source. ECC vector generation uses the
same fixed test seed on both sides.

| Variant | Callgrind instructions | Change vs reference |
| --- | ---: | ---: |
| Reference | 184,080,599,400 | — |
| Predecode + setarray | 165,194,086,031 | −10.259915% |

The profile clears the 10% instruction-count screen. Generated `.hex` and
`.vvp` manifests match, and visible simulation output matches through the
window after excluding only the heartbeat line. Callgrind's client-request
profile was counted from its `totals:` field; its `summary:` is zero.

This is a bounded screening run, not a complete firmware pass. The window VPI
plugin intentionally calls `vpiFinish` when mcycle reaches 200, so the
Caliptra wrapper records `passed=false` and no testbench finish marker. The
result does not satisfy full correctness or merge gates by itself. Prior
focused tests passed all 32 valid 4-state and malformed-metadata cases for
reference, predecode, and packed-result variants; those outputs are preserved
in `../attempt-v3-1294/results/`. The registered
`sv_class_unpacked_property_index_4state` regression also passes under the
pinned reference and candidate `vvp_reg.py` runs. Its 16 four-state inputs
match byte-for-byte using the same compiled `.vvp`; mutating its descriptor to
malformed metadata yields the same result on both runtimes across 16 repeated
iterations. Those focused logs are under `runtime-equivalence/`.

Remote job exit code: 0. Resources: 2 CPUs, 8 GiB requested; peak RSS about
1.85 GiB per side. Archive SHA-256:
`111b6c60842458fa2cd063c2ccc9d9ce35b0a8e4b604438e0c7ea6f903bab3ef`.
