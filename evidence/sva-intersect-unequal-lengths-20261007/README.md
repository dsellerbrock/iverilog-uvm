# Unequal fixed-length sequence `intersect`

Date: 2026-10-07. Scope: IEEE 1800-2017/2023 §§16.9.6, 16.12.7, A.2.10.

Unequal fixed-length `intersect` operands are legal but cannot produce a
sequence match. The default NFA engine now carries that empty language through
direct cover and implication lowering. An empty antecedent is vacuous; an
empty consequent fails when its antecedent matches. The `IVL_SVA_LEGACY=1`
opt-out keeps its explicit unsupported-shape diagnostic.

## Evidence

- `make -j1` and `make install` succeeded on Apple Silicon with the worktree
  configured for `local-install`; `iverilog -V` resolved the matching local
  backend without `/usr/local` fallback.
- `tests/sva_nfa/run.sh`: 64 passed, 0 failed.
- Strict legacy `ivtest/vvp_reg.pl` focus: 1/1 passed.
- Strict JSON/VVP focus: `-g2017` and `-g2023`, 2/2 passed.
- Explicit legacy-engine rejection under strict `-g2017` and `-g2023` exits
  nonzero with the same-length diagnostic and the matching edition citation.
- Local tool hashes: `iverilog` `8d56e848e268dc7d1de27d79a23d62eef78911d79183a1090a7a2b4502125e2b`,
  `vvp` `7795f1d9a205adbe5a0890e934417f4c02a06c6c7c405bbbed5be3b7a9562c29`,
  `ivl` `7e90dc695035bb1e41da0157ff1ea833a7f5adc80b43553ac3adcaefb7c7582d`,
  and `vvp.tgt` `0f5ed97fe08fd353a25bf54327b47dbcd093abf3842cd1102da5484e0cfbe27e`.
- The permanent reducer is
  [`intersect_unequal_lengths_nfa_only.sv`](../../tests/sva_nfa/intersect_unequal_lengths_nfa_only.sv).

The reducer covers an unequal-length `and` endpoint control, equal-length
`intersect`, an unmatched standalone unequal `intersect`, implication-cover
no-match, antecedent vacuity, and consequent failure. Variable/ranged
mismatches and broader nested combinator trees are not qualified. These are
local results; no CI qualification is claimed.

The temporary focused lists used for the legacy and JSON runner checks each
contained the registered test rows: legacy
`sv_assert_intersect_unequal_lengths normal,-g2017 ivltests gold=sv_assert_intersect_unequal_lengths.gold`;
JSON `sv_assert_intersect_unequal_lengths_2017` and
`sv_assert_intersect_unequal_lengths_2023`.
