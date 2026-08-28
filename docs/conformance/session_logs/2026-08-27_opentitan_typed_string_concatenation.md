# IEEE 1800 typed string concatenation and OpenTitan replay (2026-08-27)

Worktree
`iverilog-uvm-opentitan-typed-string-after242-arm64-20260827`, branch
`agent/opentitan-typed-string-after242-arm64-20260827`, started from
`origin/main` at `6bfe64ce55e399b8154b5fe95e5fbbdf89a6f911` after PR #242 merged.
All compiler/runtime validation used the worktree-local native-ARM64 install
through the shared resource runner. OpenTitan, Caliptra, and Accellera UVM
sources were not modified.

The normative boundary was checked against the ignored local IEEE 1800-2017
and IEEE 1800-2023 PDFs: 6.16 and Table 6-9 for string conversion and operand
categories, 11.4.12.2 for concatenation and replication, and 13.5.5 for a
zero-argument function call whose parentheses are omitted. Slang 11 was used
as a static-semantics differential, not as the standard or a runtime oracle.

## Failure and red proof

OpenTitan's Darjeeling and Earlgrey top-chip sources construct hierarchical
path parameters from string parameters, string literals, fixed unpacked arrays
of string, string-returning methods, and parentheses-free static
`type_name` calls. The previous compiler reached the typed
`PEConcat::elaborate_expr(ivl_type_t)` entry without a string case and emitted
the internal `I don't know how to elaborate(ivl_type_t)` diagnostic.

The permanent positive reducer was also run with the separately built
comparison compiler at commit
`3ae349ca2ef7cf05bbce4a1248e93b3eafbf3ee7`. Its source tree is byte-identical
to the branch merge base. That compiler reports two internal typed-expression
errors and then reaches the `elab_expr.cc` `par_string` assertion (exit 134);
the current compiler prints `PASSED`. The expanded final reducer was rerun
against the clean canonical `origin/main` compiler at
`6bfe64ce55e399b8154b5fe95e5fbbdf89a6f911` and retains that same red/main,
green/branch result.

Final review also exposed a branch-local specialization regression. In a
generic `class C #(type T)`, the branch initially checked a concat operand
declared as `T` after the unspecialized body had collapsed it to fallback
`logic [31:0]`, rejecting a valid `C#(string)` formal or property before the
concrete specialization was applied. Clean main accepts the minimal control.
The final implementation recovers the parse-form declared type, defers only
while the exact class type parameter remains unresolved, and validates each
concrete specialization. `#(string)` formal/property cases run to `PASSED`;
the paired `#(int)` negative remains a hard Table 6-9 error.

An adjacent runtime defect was exposed while checking the standards-compliant
explicit form `string'(source[1])`: the selected byte was sent through the
string-container select path and became an empty string. The selected value is
now evaluated once as a vector and converted to string in VVP. The focused
witness changed from an empty result to a one-character string with the
expected byte value.

## Normative and compatibility boundary

In the evidenced standard subset, a concatenation in a string assignment
context accepts string expressions and string literals. An all-literal group
is converted by that context; the same group remains a packed integral value
in an integral context. An uncast integral-only concatenation is not silently
accepted. A true string expression mixed with an uncast integral expression is
rejected where the operator is formed, so wrapping the concatenation in a
conditional or whole string cast does not bypass the check. An explicit cast
of the integral operand requests integral-to-string conversion and removes
null bytes.

A string replication multiplier must be integral and may be a run-time
expression. Context propagates into nested literal data, so
`{repeat_count{{"A", "B"}}}` uses the run-time string-replication path in a
direct string target, beneath a whole string cast, and in both comparison
operand orders rather than requiring a constant multiplier. Assigning that
string replication, or a concatenation containing a string expression, to an
integral target is a hard error. Zero and nonzero repeats evaluate their
operand exactly once; a zero multiplier produces the empty string.

Review hardening gives newly generated VVP an explicit `%rep/str/s` or
`%rep/str/u` opcode and removes the old `count < (1<<20)` policy from those
typed forms. A legal variable count now produces and checks a
**1,048,576-byte** string instead of becoming empty at the former boundary.
The unsuffixed `%rep/str` opcode retains its signed interpretation, silent
invalid result, and historical copy-count boundary so textual VVP images made
by older compilers keep their behavior. A pinned old-image fixture verifies
that contract independently of the current producer. At run time, the typed
forms diagnose a negative signed count, a count containing X/Z, or a value
wider than the runtime index and produce the empty result; there is no new
arbitrary language-level size ceiling. The runtime also converts a host
allocation exception into a controlled diagnostic, but that exceptional path
is source-reviewed rather than forced by a deterministic regression.

The `br_gh800` spelling `{"A", 8'o15, "B"}` is retained as a narrowly bounded
literal-only compatibility extension. It requires at least one string literal
and otherwise permits only literals, recursively; an integral variable,
select, call, or other expression is not admitted into a true string-expression
concatenation by this exception.

String indexing itself yields a byte. Slang 11 accepts the string-expression,
literal, method, static-call, and explicit-cast cases, but rejects a direct
`string[index]` operand in the string concatenation, as well as ordinary
integral variable/function and packed-vector-select operands. OpenTitan uses
the direct selected-string spelling in source intended for its commercial
simulator flow. Icarus therefore admits one deliberately narrow compatibility
extension: the final select must be 8 bits and its underlying object must have
string type. This does not admit an arbitrary byte or vector select, and it is
not recorded as IEEE behavior. VCS, Questa, and Xcelium were not available and
were not run.

For data-object and constant-string-parameter receivers, built-in string
methods now carry their declared result types through width probing, constant
folding, and lowering: `len`, `compare`, and `icompare` return `int`; `getc`
returns `byte`; `atoi`, `atohex`, `atobin`, and `atooct` return `integer`;
`atoreal` returns `real`; and `toupper`, `tolower`, and `substr` return
`string`. A nested string concatenation can itself be the receiver. The
built-ins require exactly zero arguments for the conversion/case/length
family, one for `compare`/`icompare`/`getc`, and two for `substr`; a mismatch is
one hard error before lowering. A scalar `string[index]` has byte type and is
rejected as a string-method receiver, including through direct, struct, and
class-property spellings, instead of dispatching the method on the unselected
whole string. Review also switched constant-parameter method evaluation from a
rendered representation to the string's semantic raw bytes: empty strings,
nonprinting bytes, and literal backslash/quote contents retain their correct
length, character values, case conversion, and substring.
The receiver being constant no longer forces `getc`, `compare`, `icompare`, or
`substr` arguments to be constant: variable indices and comparison operands
lower through the ordinary runtime method path. Constant string comparisons
also fold on semantic bytes, and string context reaches a concatenation in
either comparison operand order.

These arity checks do not claim complete argument-type conversion. The
pre-existing compiler accepts `s.compare(65)`, while Slang requires an explicit
integer-to-string cast. A fixed-size unpacked signal-array string element also
retains its correct two-character value but direct `sa[0].len()` reports 1;
the analogous dynamic-array, queue, and class-property fixed-array probes
report 2. Both residuals are outside this increment's method claim.

A parentheses-free zero-argument static function retains its string type in
the supported run-time concatenation. Its use in a constant `localparam`
concatenation remains rejected by the current branch, and a non-static method
called as `C::f` remains a pre-existing wrong acceptance. Slang accepts the
former and rejects the latter.

The current/baseline/Slang differential sources for these method, comparison,
class-scope, array-element, cast, and replication boundaries are retained
outside the repository under
`evidence/typed-string-review-probes-20260827.5zOjVN/`.

Zero-count string replication and once-only operand evaluation are shared
IEEE 1800-2017/2023 behavior, not a 2023-only delta. Slang 11 rejects the
standalone `{0{"A"}}` string-context reducer with `replication constant can
only be zero inside of a concatenation`. That exact oracle disagreement is
recorded without overriding the direct IEEE interpretation.

## Implementation

- `elaborate_rval_expr` routes a concatenation or conditional with a string
  destination to typed elaboration. `PEConcat` validates the operand tree at
  the operator, so an outer context cannot hide a mixed string-expression and
  integral operand. The typed entry applies destination context to nested
  literal data.
- `PEConcat::test_width` leaves literals integral outside a string context,
  carries that context from a target, cast, or comparison into nested
  run-time replication, rejects an integral multiplier type mismatch, and
  marks zero string replication as string. Its literal-only helper isolates
  the `br_gh800` compatibility rule from general integral expressions.
- A direct concat identifier recovers its formal/local `PWire` or class
  property declaration before legality is decided. The existing class-type-
  parameter provenance APIs distinguish a generic or forwarded binding from
  a concrete specialization, and the duplicate-diagnostic latch is scoped to
  the elaborating `NetScope` so one specialization cannot poison another.
- `PECallFunction::test_width_method_` records exact built-in string-method
  results. Shared dispatch validates arity before constructing a call,
  constant-parameter method evaluation preserves the result category and raw
  semantic bytes, and receiver traversal rejects a selected string byte.
  `PEIdent::test_width` and elaboration retain the return type and execute the
  real zero-argument static function, including a dependent `T::type_name`,
  instead of using the older compile-progress substitution.
- Typed cast elaboration sizes its source before conversion. Constant folding
  retains `NetECString` identity and removes canonical null bytes rather than
  returning string-looking vector bits.
- `PEIdent::is_string_byte_select` recognizes only the documented OpenTitan
  compatibility spelling without evaluating its index. VVP's string evaluator
  converts selected integral values explicitly, which also fixes the ordinary
  explicit-cast path.
- VVP evaluates one complete string-concatenation unit once, then applies the
  string repeat operation. This preserves side effects for nonzero repeats and
  still evaluates the operand once when the multiplier is zero. Each repeat
  allocates its own VVP index word, so evaluating a bounded-queue RHS cannot
  overwrite the caller's live maximum index. Review hardening preserves
  signedness while loading the runtime count, emits distinct typed opcodes,
  validates runtime index state and representable result size, and keeps the
  unsuffixed opcode as a documented old-image compatibility contract.

## Permanent regressions and validation

The paired positive reducer
`sv_typed_string_concat_context{,_2023}` checks the exact Darjeeling scalar
path and Earlgrey fixed string-table shapes; empty and nested literals; constant
and run-time string replication, including nested all-literal replicated data
in direct-target, whole-cast, and both comparison contexts; zero replication;
once-only operand evaluation for zero and nonzero counts; operand and
whole-expression casts; packed literal control; folded `.len()`; procedural
concatenation; the exact built-in `int`,
`byte`, `integer`, `real`, and `string` result types for data objects and
constant string parameters; a nested-concatenation method receiver; direct and
dependent parentheses-free static `type_name`; the narrow selected-string
compatibility spelling; and the standards-compliant explicit selected-byte
cast. It also checks generic-class formal and property operands specialized as
`string`; semantic empty/nonprinting/backslash/quote parameter
bytes, exact parameter-method conversion result types, runtime method
arguments on a constant receiver, comparison operand-order symmetry and
relational folding, bounded-queue index isolation for constant and variable
repeats, and a legal **1,048,576-byte** variable repeat through its length and
final character.

Paired negative reducers pin:

- an integral-only concatenation;
- a mixed string/integral concatenation;
- a generic-class operand concretely specialized as `int`;
- a procedural known-integral variable;
- a string-typed replication multiplier;
- string replication and a string-expression concatenation assigned to an
  integral target; and
- an ordinary packed-vector byte select plus an integral-returning
  parentheses-free static function and a selected-string-byte method call.

The paired `sv_typed_string_method_arity_fail{,_2023}` reducers require exact
hard errors for the zero-, one-, and two-argument built-in families on data
objects and constant string parameters. External review probes additionally
confirm operator-local rejection beneath a conditional and whole string cast,
and distinguish direct/class-property byte selects from legal string-array
elements.

The paired `sv_typed_string_repeat_runtime_error{,_2023}` runtime reducers pin
the signed negative, X/Z, and index-width-overflow diagnostics and verify that
each invalid result is empty.

`run_string_repeat_ir_compat.sh` executes a pinned textual VVP image containing
the historical unsuffixed opcode, checks that the current producer emits one
signed and two unsigned typed forms for the fixture, and executes the new
image. This separates consumer compatibility evidence from producer/consumer
round trips.

Measured native-ARM64 results at this checkpoint:

| Gate | Result |
|---|---:|
| focused legacy | **23/23 passed** |
| focused JSON/VVP | **24/24 passed** |
| full legacy | **2,083/2,083 passed** |
| full JSON/VVP | **1,161 entries, 0 failed**; **1,144 executed/pass + 17 NI** |
| negative diagnostics | **136/136 passed** |
| VPI | **103/103 passed** |
| textual VVP repeat compatibility | **6/6 passed** |
| canonical unmodified real-DPI UVM | **354/354 passed**, 0 failed, 0 skipped; real DPI loaded |

## Authentic OpenTitan frontier

The unmodified Darjeeling and Earlgrey top-chip compile invocations were
replayed with an earlier same-branch compiler before the final generic-class
deferral hardening. Their former internal typed-string diagnostic counts move
from **10 and 18** to **0 and 0**. Neither replay log
contains the new focused `String concatenation operand` diagnostic.

For both tops, the first independent diagnostic is now:

```text
src/lowrisc_dv_spi_agent_0.1/spi_agent_cfg.sv:139: error: the type of the variable 'data' doesn't match the context type.
```

That site compares a queue of four-state bytes with a dynamic array of
two-state bytes. Both invocations then traverse more than 335,000 lines of
later, independent warnings and errors before the compiler segfaults and
produces no VVP image. The tops therefore still do not elaborate, and this is
frontier movement rather than an OpenTitan pass. Evidence is outside the
repository under
`evidence/opentitan-typed-string-after242-arm64-20260827/top-chip-replay-resolved/`.

The final narrow deferral change was not replayed across those tops. No new
full 61-target OpenTitan matrix was run for this increment. The last
matrix remains **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS** and must not be
reclassified from these two top replays.

Caliptra was not rerun. Its last audited 105-job static census remains **52
PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT / 0
ICARUS_GAP**: 52 clean cases and 53 debt/shared-source cases. That is static
compile/elaboration/synthesis differential evidence, not broad DV runtime.

## Remaining boundaries

- A fixed-size unpacked signal-array string element has the correct stored
  value but a wrong direct method value: `sa[0]` stores `"AB"`, while
  `sa[0].len()` reports 1. This is pre-existing; dynamic arrays, queues, and a
  fixed array in a class property return 2 in the differential probe.
- String-method argument *types* remain separate from the now-hard arity
  checks: `s.compare(65)` is a pre-existing wrong acceptance. The reverse
  mixed comparison `{8'h41} == s` is likewise accepted by both the merge base
  and this branch, while Slang rejects it; the positive literal form
  `{"A"} == s` remains legal.
- A parentheses-free static class call in a constant `localparam`
  concatenation is rejected by the current branch; the merge-base compiler
  was already broken on the same source by a different internal typed result.
  Class-scoped invocation of a non-static method without an object is a
  separate pre-existing wrong acceptance.
- Direct `string[index]` concatenation remains a labeled compatibility
  extension, as does the `br_gh800` literal-only group; commercial-simulator
  differential evidence has not been run.
- The independent `spi_agent_cfg.sv:139` queue/dynamic-array context mismatch
  is the next useful OpenTitan reducer.
- The later full-graph compiler segfault requires its own reduced reproducer;
  it is not hidden by this string fix.
- Full OpenTitan matrix and Caliptra application replays remain outstanding.
