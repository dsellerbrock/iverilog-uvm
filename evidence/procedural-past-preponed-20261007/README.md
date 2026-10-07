# Procedural `$past` Preponed sampling — DD-104

## Result

The procedural sampled-value sampler now saves static signal operands from
the Preponed value, even when a blocking writer declared earlier in the source
updates the same signal on that edge. The shared fix covers inferred-edge,
explicit-event, and default-clocking routes in the tested strict IEEE
1800-2017 and 1800-2023 cases.

The sampler still advances independently of whether the reader blocks. Its
history update remains NBA, and generated history-enable calls run before
the first sampling edge. The implementation reuses the existing
`$ivl_clocking_sample` path rather than changing VVP scheduling.

The regression also exercises a simple automatic local: `$past(local_value)`
uses its current value. Automatic operands are classified while their lexical
scope is live; unsupported direct automatic forms such as `$past(local_value,
2)` fail with a sampling/lifetime diagnostic. A compound automatic operand
fails elaboration instead of being sampled through a detached process.
Clocking-input operands are explicitly diagnosed as unsupported rather than
being wrapped and mis-sampled; paired 2017/2023 compile-error tests cover this
boundary.

## Baseline and implementation

Before the change, the writer-first reducer failed at tick 2 with
`$past(d)=1` instead of `0`, and at tick 3 with `2` instead of `1`. The same
failure was reproduced through the legacy and strict JSON/VVP paths in both
editions.

The shared procedural capture and history-enable helpers wrap supported
static operands before building the independent history process, so the
Active-region sampler reads their Preponed values. The helpers are used for
inferred edges, explicit clock events, and default clocking. They enable each
associated signal history during initialization. Automatic direct identifiers
are classified during parsing while their declaring scope is valid; a simple
current-value substitution is made in the original reader process.
Unsupported automatic and clocking-input shapes are not sent through the
detached sampler.

## Validation

Built and installed serially with `make -j1 install`.

From `ivtest/`:

```sh
PATH=../local-install/bin:$PATH perl vvp_reg.pl regress-sampled-value-preponed-focus-legacy.list
PATH=../local-install/bin:$PATH python3 vvp_reg.py regress-sampled-value-preponed-focus-vvp.list
```

Results: **5/5** legacy rows and **10/10** JSON/VVP cases passed. The totals
include one legacy and two paired strict compile-error checks for unsupported
clocking-input operands. Both harnesses cover the writer-first reducer,
existing procedural sampled-value controls, default clocking, and explicit
clock events under strict `-g2017` and `-g2023`.

Two temporary compile probes confirmed fail-closed behavior: `$past` of an
automatic local with a tick-count argument emits a specific
16.5.1 sampling/lifetime error; a compound automatic expression fails
elaboration because the detached sampler cannot bind the block-local
variable. No full regression, OpenTitan census, or Caliptra run was needed.

Source-built image SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| `iverilog` | `f646fa5eaaf615b89fdd508c60ac4bff6a38e795197b76100b7da6c8fcdd0aa7` |
| `ivl` | `b5b2c65af2330bb4d4219cc66f39ed8240b41f8ee9a0a2a689fd3c2a829b2623` |
| `vvp` | `da3ecdef09ef8bf415465b203eeffa076bc68423a39c3cfa39888efd2791872c` |
| `vvp.tgt` | `404a3620fc341d4746a77d7f89086505ccbbf35a7a95832b896ab32b3138dfb1` |

## Boundary

This qualifies the tested static signal and simple direct automatic-variable
forms across the three clock-source routes. Clocking-input operands and wider
automatic expression/lifetime forms remain unsupported and are diagnosed or
fail elaboration. This does not close clause 16; unsupported expressions must
not silently use a live value.
