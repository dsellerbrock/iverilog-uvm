# Open and closed issue dedupe: named property as implication consequent

Fetched every issue from `dsellerbrock/iverilog-uvm` with `gh issue list --state all --limit 1000` on 2026-10-21 and retained the result in [`dedupe-all-issues.json`](dedupe-all-issues.json). It contains 421 issues: 294 open and 127 closed. Searched titles and bodies across both states for named-property, property-instance/instantiation, implication operand/consequent, unbound property and §16.12 terms.

No open or closed issue describes a named property failing to bind when used as the consequent of `|=>`. Relevant near matches are distinct:

- #874 (open) covers a standard multiclock `if-else` property with property/sequence branches rejected and dropped; it does not cover a named property as an implication consequent.
- #721 (open) covers the absent property `or`/`and` operators in the `property_expr` grammar.
- #725 and #726 (open) cover typed and local property formal arguments.
- #896 (open) covers binding `source_seq.matched` for a cross-clock sequence, not named property instances.
- #446 (open) covers finite ranged multiclock antecedent behavior.
- #720 (open) covers mismatched `endproperty` labels.
- #475 (closed) covers mixed-type assertion-local declarations; #470 (closed) covers pass actions on non-fanout assertion paths.
- #16 and #18 (closed) are broad earlier SVA milestones, without this specific binding behavior.

The existing matrix row for §§16.12.1–16.12.3 recorded direct property instantiation and implication behavior as passing. N3b confirms direct named-property assertion works; N3a/N3d isolate the uncovered nested `|=>` consequent form. The lead confirmed this is distinct and filed [#918](https://github.com/dsellerbrock/iverilog-uvm/issues/918). The snapshot predates that filing, so it correctly contains 421 issues (294 open, 127 closed).
