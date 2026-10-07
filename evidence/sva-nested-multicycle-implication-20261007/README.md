# Nested implication with multi-cycle antecedents

Fix 40 qualifies nested property-expression consequents from IEEE 1800-2017
§16.12.7. The outer antecedent may span multiple ticks; the nested antecedent
starts at its match endpoint for `|->` and at the following tick for `|=>`.
Lowering now represents that boundary as overlapping or nonoverlapping
sequence concatenation.

The regression in `tests/sva_nfa/nested_multicycle_implication_nfa_only.sv`
checks both outer operators with multi-cycle inner antecedents. Its expected
failure count is two, one per assertion. It passes under strict `-g2017` and
`-g2023` with the NFA/VVP runtime. Legacy mode rejects the NFA-only sequence
composition with the expected `sorry` diagnostic.

```sh
make -j1 install
for standard in 2017 2023; do
  IVL_SVA_NFA=1 local-install/bin/iverilog -g"$standard" \
    -s nested_multicycle_implication_nfa_only \
    -o /tmp/nested.vvp tests/sva_nfa/nested_multicycle_implication_nfa_only.sv
  local-install/bin/vvp /tmp/nested.vvp
done
```

Expected output: `nested multi-cycle failures=2 (expect 2)` in each mode.
This does not qualify nested multiclock properties, `disable iff`, or the full
set of temporal property operators; those remain under G12.

The adjacent `tests/sva_nfa/run.sh` run reported 62 passes and one mismatch in
`seq_or_and_nfa_only`: the assertions emitted the same event lines as its gold
file, but in a different order. The case contains no implication and does not
call the changed nested-implication lowering. Sorting both streams produces
an exact match; the order-sensitive suite remains not fully green.
