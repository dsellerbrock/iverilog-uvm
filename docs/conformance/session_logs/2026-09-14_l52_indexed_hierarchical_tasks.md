# L52 — Execute task calls through indexed hierarchy

`child dut[1:0]` followed by `dut[1].bump()` compiled but discarded the call,
leaving both instance counters zero. `indexed-hier-task-results.json` records
the failing runtime assertions in both editions. A runtime-indexed array of
class objects executes correctly in the separate
`indexed-object-task-control.json` control.

IEEE 1800-2017/2023 13.3, 23.6 and 23.8.1 distinguish constant-selected
hierarchical instances from runtime-selected objects. Hierarchical task enables
must resolve and execute the named subroutine; instance selections must name
legal instances. Receiver lookup now identifies actual scopes before taking
the earlier indexed-object fallback, allowing ordinary task/function lookup
to handle those scopes.

The shared scope-index evaluator rejects unknown values and values outside
its supported integer representation instead of narrowing them to an unrelated
instance. Receiver lookup also diagnoses out-of-range selections of a known
instance array. Full-width scope-index representation remains a separate
compiler limitation; these diagnostics do not claim that IEEE indices are
restricted to the implementation's integer width.

Focused legacy 5/5 and JSON 10/10 pass. Permanent tests check task timing,
arguments, copy-out and selected-instance effects in module arrays and generate
blocks, indexed void functions, and runtime-indexed object methods. Missing
members, nonconstant/unknown indices, out-of-range indices and a 128-bit alias
candidate are diagnosed. A root control also verifies legal negative instance
indices, including INT_MIN, in both editions (`l52-negative-index-control.json`).
This is the tenth focused increment before one combined regression batch. Broader class fallback
and unindexed missing-task handling remain separate obligations.
