# L60 — Runtime fixed-array element increment and decrement

Increment/decrement expressions on fixed unpacked-array elements generated
scalar storage operations. Integral elements crashed VVP; real elements
lost index effects and updates or aborted. IEEE 1800-2017 and 1800-2023
11.4.2 require correct prefix/postfix values and operand updates; 7.4.6
supplies typed defaults and suppressed stores for invalid indices.

The target now captures the normalized array index once, preserves its
validity across the operation, and uses existing array load/store opcodes.
Integral two-state values are converted at the read/update boundaries;
real increment and decrement share one emitter. Array consumers reject
unknown and overflow flags and check native-width bounds before narrowing.
The shared real/string store helper follows the same validity rule.

Unary elaboration reuses procedural lvalue validation, rejecting const
array writes. It preserves whole array-element identity when an invalid
literal index would otherwise fold the operand into a read-value constant.
Reconstruction excludes packed subselects and nested lvalues.

## Focused evidence

Evidence root: `evidence/runtime-array-increment-assessment/`.

- Original baseline: 32 failing paired runs across four element types and
  all four pre/post increment/decrement forms.
- Independent boundary tests cover 108 semantic cases per edition:
  ascending/nonzero/negative ranges, valid/OOB/X/Z/signed 128-bit indices,
  exact selector-call counts, and unchanged neighboring elements.
- Independent review includes indices above 32 bits, int/real automatic
  recursion, multidimensional coordinates, shared real/string store controls,
  const/net negative controls, and literal-invalid int/logic/real operands.
- Eight L58 constant-result probes that previously emitted unresolved-functor
  startup warnings now execute cleanly because their emitted array-function
  bytecode is valid.
- Latest root checkpoint: 94/94 expected outcomes and ten existing
  increment, genvar, real-array, string-array, and assignment neighbors.
  Six literal-invalid probes retain ordinary out-of-range compile warnings;
  runtime results are exact and stderr is empty.
- Final `root-frozen-results.json`: 94/94 expected outcomes, stable hashes;
  six additional literal-X checks pass in both constant and runtime contexts
  (`static-extra/results.json`). Ten existing neighboring regressions pass.
- Final permanent lists: legacy 4/4 and JSON 8/8, `l60/*final-5.*`.
  The original index converter is retained: isolated replay confirms 24/24
  boundary runs pass when its consumers correctly reject the overflow flag.
  There is no change to preponed-array sampling in this feature.

Compiler SHA-256: `0f6667add55e883ff9752b769528445095f63eb4ceed0f3cf52df34cafcc13d4`.
Target: `78e456f93901f2ccd463e971e0e4320b5ae9eb6371d107883cf252545dd6dfff`.
Runtime: `a6788f42934e9bb16a0b1409408c84a776033727ff8aaba8d37c20b269c3bc76`.

## Remaining scope

L60 was fast-forwarded into local main as `bceb03f89`, bringing the batch
to eight focused features; full suites remain deferred until approximately ten.
The last broadly qualified semantic baseline remains `c686a4781`.

DD-028 tracks missing class-property updates and real property aborts.
DD-029 tracks wide string-array reads aliasing a valid element. DD-030 tracks
packed-select increments that reach the backend and abort when result widths
match the selected width; widened-result rejection does not close that gap.
No application sources, remote branches, or additional worktrees were changed.
