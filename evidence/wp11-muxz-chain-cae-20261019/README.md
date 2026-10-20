# WP11 MUXZ-chain fusion screen — rejected

Measurement base: `cae035642e056644274a01e98d4422ce286685b4`.

This prototype fused nested, zero-delay, strong-drive `MUXZ` chains whose
intermediate outputs are compiler-generated `_ivl_` nets. It emitted 64 fused
operators for `rtl_alu`. The candidate and reference produced byte-identical
`rtl_alu` output. A separate exhaustive four-state check covered all 64
selector combinations and, per output bit, all 256 combinations of four-state
data inputs; its outputs also matched.

The temporal check rejected the candidate. In
[`muxz_chain_delta.sv`](input/muxz_chain_delta.sv), `s0` changes and an
`always @(s0)` process then changes `s1`. Stock VVP reports only the initial
`y=0`; the fused build reports `y=1` and then `y=0` at time 1. The output `y`
is named and observable, so reducing the propagation steps changes its
value-change trace. The candidate was reverted before any Slurm performance
screen; no performance claim or PR is made.

Reference/candidate outputs and the rejected implementation patch are retained
here. `candidate.patch` has SHA-256
`341ff55467439019733ea6fbbed6a6d70ed9825e473ffc06ab73f938b06f3e9c`.
