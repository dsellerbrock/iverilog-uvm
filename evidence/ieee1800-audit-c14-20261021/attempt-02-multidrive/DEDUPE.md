# Open and closed issue dedupe

Queried all 412 issues in `dsellerbrock/iverilog-uvm`, open and closed, with `gh issue list --state all --limit 1000 --json number,title,state,url,body`. The complete query snapshot is `dedupe-all-issues.json`. Search terms covered §14.16.2, the associated-output-clockvar restriction, continuous assignments and primitives driving clockvar variables, last-drive behavior, multiple clocking blocks, §16.5.1, sampled values, Preponed sampling, default sampled values, const casts, assertion action blocks, and Reactive scheduling.

## Clause 14.16.2

| Issue | State | Relationship |
|---|---|---|
| [#674](https://github.com/dsellerbrock/iverilog-uvm/issues/674) | open | Unpacked **net** clockvar targets; per-element drivers and resolution with other drivers. This tranche uses scalar or packed targets, so the target-shape gap is distinct. |
| [#438](https://github.com/dsellerbrock/iverilog-uvm/issues/438) | closed | 1D fixed-unpacked **variable** outputs; distinct target shape and variable/net kind. |
| [#908](https://github.com/dsellerbrock/iverilog-uvm/issues/908) | open | Blocking and regular intra-assignment-delay writes to clockvars; N7 checks external continuous, primitive, and procedural-continuous drivers instead. |

Exact phrase searches for “associated with an output clockvar”, “continuous assignment clocking output”, “clocking output primitive”, and “multiple clocking blocks” found no other matches. “last drive” matched #878 only, an unrelated `trireg` issue.

## Clause 16.5.1

| Issue | State | Relationship |
|---|---|---|
| [#496](https://github.com/dsellerbrock/iverilog-uvm/issues/496) | closed | Procedural `$past` operand capture in Preponed; this tranche probes concurrent assertion expression sampling. |
| [#709](https://github.com/dsellerbrock/iverilog-uvm/issues/709) | open | Procedural `$sampled` returning a live value; S1/S2/S5 use concurrent property expressions. |
| [#711](https://github.com/dsellerbrock/iverilog-uvm/issues/711) | open | Clocking-block inputs in sampled-value functions; not exercised here. |
| [#712](https://github.com/dsellerbrock/iverilog-uvm/issues/712) | open | Global-clock past/future sampled-value functions; not exercised here. |
| [#653](https://github.com/dsellerbrock/iverilog-uvm/issues/653) | open | Sequence `.triggered` binding at time zero; unrelated to default sampled values. |

Other title/body matches were #715 (assertion-variable declaration assignments), #706 (deferred-assertion task actions), #864 (assertion controls), #481 and #7 (coverage/assertion umbrella). #470 is closed and covers runtime omission of vacuous assert pass actions; it does not cover deleted `cover property` pass statements. The lead separately searched all 412 open and closed issues for “cover pass action dropped” and “recorded corner” before filing #911; neither found a duplicate. Exact “default sampled value”, “const cast”, and action-block/Reactive phrase searches returned no issue.

The broader cast search found #754 (`type()` as a cast type), #750–#746 (bit-stream casts), #745–#741 (task-form `$cast`), and #611 (class-scoped type-parameter cast). These use different cast forms; no open or closed issue mentions the `const'` cast exercised by S6.

The search snapshot predates the resulting issues and does not contain them. After the paired evidence, the lead filed [#909](https://github.com/dsellerbrock/iverilog-uvm/issues/909) for N7a–N7c as one shared §14.16.2 restriction gap, [#910](https://github.com/dsellerbrock/iverilog-uvm/issues/910) for unsupported `const'` casts, and [#911](https://github.com/dsellerbrock/iverilog-uvm/issues/911) for dropped `cover property` pass statements. #909 is distinct from #908 (writes to the clockvar itself) and #674 (unpacked net targets). #910 is distinct from the other cast issues listed above.
