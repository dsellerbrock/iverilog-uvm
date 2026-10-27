# §8.23 / §8.26 specialized type-scope reducers

Slurm job 3495 ran S1–S5 under `-g2017` and `-g2023` on the pinned Icarus 13.0-devel `cc25756d1` compiler. Every form failed to compile in both editions (rc 2); no simulation ran.

| Case | Form | First diagnostic in both editions |
|---|---|---|
| S1 | `P#(bit)::T2 v1;` — specialized ordinary-class typedef in a variable declaration | `syntax error`, followed by `Invalid module instantiation` |
| S2 | `IA#(bit)::T2 v2;` — specialized interface-class typedef in a variable declaration | `syntax error`, followed by `Invalid module instantiation` |
| S3 | `IB#(bit)::T2 v3;` — typedef inherited through interface-class `extends` | `syntax error`, followed by `Invalid module instantiation` |
| S4 | function return type `P#(bit)::T2` | `syntax error`, followed by `I give up on this function definition.` |
| S5 | function return type `IB#(bit)::T2` | `syntax error`, followed by `I give up on this function definition.` |

The exact source snapshots, compiler hashes, result table, and full diagnostics are preserved in `input/`, `results/`, and `logs/`.

Open-and-closed dedupe found existing open issue [#766](https://github.com/dsellerbrock/iverilog-uvm/issues/766), whose tests cover specialized class-scoped types in variable, typedef, and class-property declarations; its body says such types should work wherever a data type is accepted. S1–S3 are directly covered. S4/S5 add the untested function-return position but appear to be the same specialized-class-scope limitation. The audit lead will decide whether to comment on #766 or file a distinct issue. No new issue was filed from this probe.

IEEE 1800-2017 §8.23 and §8.26.3, pp. 196–198, and the corresponding 2023 clauses permit these type selections; the lead confirmed the specialized `class_scope` syntax against Annex A.
