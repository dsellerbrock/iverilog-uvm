# Grouped explicitly clocked implication consequent

Baseline: `c22dceab7`; focused implementation evidence, pending batch qualification.

Unmodified OpenTitan Earlgrey-PROD-M6 `adc_ctrl_fsm_sva.sv` uses a grouped
explicitly clocked implication consequent. The grouped form failed parsing,
while the equivalent ungrouped form already reached multiclock lowering.
IEEE 1800-2017 and 2023 Annex A.2.10 permit grouping property expressions;
16.13 specifies the overlapping and strictly future nonoverlapping clock boundary.

The parser now retains the clocked sequence wrapper through grouping. The
existing implication helper assigns its boundary, reusing the same multiclock
lowering as the ungrouped form. Further clock transitions remain on the wrapper.
This does not establish support for every recursively clocked property operator.

## Validation

`sv_assert_grouped_clocked_consequent.v` compares grouped and ungrouped forms
and independently checks exact pass/fail counts for seven cases: distinct clocks
with both implication operators, coincident clocks with both operators, disabled
pending obligation, a false consequent, and a third-clock transition after the
explicit consequent clock. Triple parentheses exercise nesting.
Both `-g2017` and `-g2023` pass: legacy harness 2/2, JSON harness 2/2.
Existing multiclock JSON neighbors: 252 run, zero failures.
Bison conflict counts remain 572 shift/reduce and 1122 reduce/reduce.

Focused command (installed candidate on PATH):

```
bash .github/ivtest_focus_gate.sh regress-grouped-clocked-property-legacy.list regress-grouped-clocked-property-vvp.list
```

Raw build, install, focused and neighbor logs:
`evidence/review-20260920/next-clocked-property/`.
The earlier application replay used its recorded compiler fingerprints; these
focused tests do not establish a new whole-application or broad qualification.

## Original application source check

At `e384b5dcc`, the original M6 `lowrisc:dv:adc_ctrl_sva:0.1` compile
command was replayed against the retained, unmodified FuseSoC source list.
The original 15 parser/cascading errors are gone: compiler exit zero, no
warning/error diagnostic (only the DPI-export informational note).
This is a compile-only check, not a simulation or formal proof result.
Exact command and output are retained in `next-clocked-property/adc-source-retest.json`
and `adc-source-retest.log` under the evidence directory above.
