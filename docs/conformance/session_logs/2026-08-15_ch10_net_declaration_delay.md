# 2026-08-15 — Chapter 10 net declaration delays

## Starting evidence

The pinned `sv-tests` source
`chapter-10/10.3.3--cont-assignment-net-delay.sv` declares `wire #10 w;`
and drives it with a separate continuous assignment. Slang
`11.0.415+8acc660a2` accepts the source, while the previous Icarus frontend
stopped at the declaration with a `sorry` diagnostic.

IEEE 1800-2023 10.3.3 distinguishes a delay on the declared net from the
delay on a declaration assignment. A pure vector net delay acts on each bit;
a vector declaration assignment and an ordinary delayed continuous assignment
act on the complete right-hand-side value. Table 28-9 supplies transition
selection for net delays, including the minimum applicable delay for a target
X. Section 23.3.3.7 and Table 23-1 determine which net type and delay survive
when compatible module ports collapse.

## Implementation boundary

The parser stores a declaration's shared delay descriptor on every declared
net. Elaboration resolves the undelayed drivers on a hidden net and crosses a
single delayed boundary to the public net. Direct l-value drivers, implicit
pulls, ports and aliases all enter the raw resolver; there is no external-net
pointer redirected to one module instance.

VVP has explicit per-bit (`.delay/v`) and whole-vector (`.delay/w`) delay
nodes. Per-bit pending updates use time buckets plus intrusive constant-time
cancellation handles and store only the bit index and scalar value/strength.
A 65,536-bit transition therefore avoids a full-vector copy per bit and avoids
quadratic insertion or cancellation. Obsolete wakeups consume their token and
always re-arm the next bucket, including cancel-to-empty and replacement paths.
Outstanding wake times are tracked explicitly, so repeated short events while
one long bucket is pending cannot enqueue duplicate callbacks for that bucket.

Collapsed module ports implement the complete frontend net-kind subset of
Table 23-1: wire/tri, wand/triand, wor/trior, tri0, tri1, uwire, supply0 and
supply1. Dominant actual/declared type and delay metadata propagate across all
aliases. Pull net types are canonicalized to one explicit pull carrier before
collapse, preventing chained or elaboration-order-dependent loss. `trireg`
continues to be rejected by its existing focused frontend diagnostic.

## Permanent evidence

The legacy and JSON/VVP focus lists cover the exact pinned declaration,
one-/two-/three-delay transition selection, X and mixed vector transitions,
inertial replacement and stale-wakeup paths, the pure-net versus
whole-assignment vector boundary, direct and noncollapsed port paths, module
arrays, all 64 Table 23-1 type pairings and all 22 warning cells, chained
tri0/tri1 and supply pull orderings, standard-order drive strengths, the
historical post-data-type strength extension, an invalid delay expression,
and a 65,536-bit resource reducer.

Annex A's `net_port_type` contains no delay production. The port reducer
therefore covers the legal non-ANSI spelling—an untyped input, output or inout
direction declaration followed by a separate delayed net declaration—and an
exact negative pins rejection of inline `input/output/inout wire #(...)`
spellings in both ANSI and non-ANSI headers. Slang rejects those inline forms
as well.

The standards-order strength-plus-initializer form is also accepted by Slang.
Slang rejects the legal pure-net strength-without-initializer form as requiring
an initializer and rejects Icarus's historical post-data-type strength spelling;
the regression records those as differential/tool-extension boundaries rather
than weakening the IEEE grammar. Delay-expression synthesis failure deletes
the caller-owned temporary expression on both success and failure paths.

The main parser retains 535 shift/reduce and 1115 reduce/reduce conflicts with
the normalized 201-state baseline signature. The VVP parser retains its
13 shift/reduce and 5 reduce/reduce conflicts. Malformed dynamic-delay bytecode
with a nonzero decay flag produces a compiler diagnostic rather than reaching
an assertion.
