# Pinned sv-tests nonpassing cases — 2026-10-13

## Baseline

The pinned run used sv-tests `c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7`, UVM
`656f20d087370a7c742e00188d20bbf30fa95339`, and Icarus source
`a15ae5be50b3b782c2590711cc4861a01ef11f6c` (13.0 devel). Slurm job 792 ran
all 1,027 applicable cases with the project's guarded runner: 603 passed and
424 were nonpassing (58.71%). The binary fingerprints, build environment,
runner, command, archive digest, result summary, and failing logs are preserved
in [`evidence/sv-tests-gap-20261013`](../../evidence/sv-tests-gap-20261013/README.md).

These counts use the same custom pass definition as the 603/1,027 milestone
start value. The separate legacy HTML rate is not mixed into this baseline.

## Classification

[`sv_tests_gap_2026-10-13.csv`](sv_tests_gap_2026-10-13.csv) contains one row
per nonpassing case, its runner result class, one primary feature area, the
observed diagnostic or outcome, disposition, test tags, raw-log path, and
whether the source and raw log were manually checked.

Each case is assigned to one primary feature area; a UVM-tagged case is grouped
under the shared UVM import failure even if its test is about assertions,
constraints, or classes. This prevents counting the same masked failure in
several feature groups. The row's `observed_root_cause` records the evidence:
explicit `sorry` diagnostics, parser/elaborator rejection, crash site, or
runtime mismatch. A syntax error without a more specific diagnostic is not
claimed as a confirmed internal code root cause; it remains a candidate for
source and IEEE review before a patch.

| Runner result class | Cases |
| --- | ---: |
| Unexpected reject | 288 |
| Degraded / unsupported diagnostic | 111 |
| Unexpected accept of expected-negative test | 13 |
| Compiler crash | 8 |
| Runtime semantic mismatch | 4 |
| **Total nonpassing** | **424** |

The 101 UVM rejects share one observed failure: the pinned UVM source's
`import "DPI-C" context function` at `third_party/tests/uvm/src/dpi/uvm_hdl.svh:77`
is rejected with a syntax error. The 13 expected-negative accepts need
clause-by-clause oracle review. Six class-only cases report that there is no
top-level module; they are held out of feature ranking until their intended
runner mode is confirmed.

## Ranked feature areas for the five implementation increments

Counts below are nonpassing cases after excluding expected-negative accepts
and no-top-level runner cases. These are candidate areas, not a claim that
every case is already proven standards-valid. Each implementation increment
still needs a reproduced minimal case, direct IEEE clause review, a confirmed
root cause, and its focused/regression gates.

| Rank | Primary feature area | Candidate cases | Total cases in area | Main observed pattern |
| ---: | --- | ---: | ---: | --- |
| 1 | UVM DPI import | 101 | 101 | Shared parser rejection at `uvm_hdl.svh:77` |
| 2 | Arrays, aggregates, and unions | 94 | 97 | Unpacked structs, associative arrays, assignment/streaming forms, and array methods |
| 3 | Class, OO, and type resolution | 56 | 56 | Class-member, out-of-block method, and type-scope rejects |
| 4 | Constraints and randomization | 52 | 58 | Unsupported constraint forms and parser rejects; six no-top cases excluded |
| 5 | Procedural, events, and timing | 34 | 35 | Event controls, clocking blocks, and procedural keywords; one expected-negative accept excluded |

The remaining candidate groups are expressions/types/operators (31),
assertions/SVA (19), directives/coverage/interfaces/system functions (11),
and other/testbench cases (7). Those remain classified but are below the
initial five by candidate count.

## Manual source/log audit

I checked the pinned source and corresponding raw Icarus log for these 30
cases. The findings below describe what the source and log show; tags are the
corpus's intended section labels, not substitutes for IEEE review.

| Area | Test case | Source/log finding |
| --- | --- | --- |
| UVM | `tests/uvm/uvm_files.sv` | Rejects at the shared DPI import in `uvm_hdl.svh:77` |
| UVM | `tests/testbenches/uvm_agent_active.sv` | Same shared DPI import location |
| UVM | `tests/testbenches/uvm_test_run_test.sv` | Same shared DPI import location |
| UVM | `tests/chapter-16/16.10--property-local-var-uvm.sv` | Same shared DPI import location; assertion body is not reached |
| UVM | `tests/chapter-18/18.7--in-line-constraints--randomize_0.sv` | Same shared DPI import location; randomization body is not reached |
| Constraints | `tests/chapter-18/18.5.14--soft-constraints_0.sv` | Parser rejects `soft b > 4` in the constraint block |
| Constraints | `tests/chapter-18/18.5.11--static-constraint-blocks_0.sv` | Explicit `Constraint declarations not supported` diagnostic |
| Arrays/aggregates | `tests/chapter-7/arrays/associative/alloc.sv` | Typed associative index is rejected; elaborator asserts at `elab_expr.cc:4908` |
| Arrays/aggregates | `tests/chapter-7/arrays/associative/methods/size.sv` | Same typed-index reject and elaborator assertion |
| Arrays/aggregates | `tests/chapter-7/structures/unpacked/default-value.sv` | Explicit `Unpacked structs not supported` diagnostic |
| Arrays/aggregates | `tests/chapter-7/queues/slice.sv` | Runtime assertion output contains mismatched slice values |
| Arrays/aggregates | `tests/chapter-11/11.4.14.3--unpack_stream.sv` | Explicit `Streaming concatenation not supported` diagnostic |
| Arrays/aggregates | `tests/chapter-5/5.11-arrays-key-index.sv` | Parser rejects the keyed assignment pattern |
| Arrays/aggregates | `tests/chapter-7/structures/packed/default-value.sv` | Accepted although the test marks packed-struct member defaults invalid |
| Arrays/aggregates | `tests/generic/typedef/typedef_test_25__bad.sv` | Accepted although the test marks undefined parameters invalid |
| Arrays/aggregates | `tests/generic/typedef/typedef_test_28__bad.sv` | Accepted although the test marks a missing forward typedef invalid |
| Class/OO | `tests/chapter-8/8.24--out_of_block_methods.sv` | Explicit `External methods are not yet supported` diagnostic |
| Class/OO | `tests/generic/class/class_test_7.sv` | Package-scoped base type `Package::Bar` is not resolved |
| Procedural/events | `tests/chapter-15/15.5.1--named-event-trigger-blocking.sv` | Parser reports `event e` as an invalid class item |
| Procedural/events | `tests/chapter-14/14.3--clocking-block.sv` | Parser rejects the clocking block as an invalid module item |
| Procedural/events | `tests/chapter-9/9.4.2.3--event_conditional.sv` | Parser reports the `iff` event control as invalid |
| Procedural/events | `tests/chapter-9/9.4.2--event_control_sim_minimal.sv` | Runtime assertion output shows a mismatch in the event-trigger sequence |
| Procedural/events | `tests/chapter-12/12.4.2--priority_if.sv` | Parser rejects `priority if` |
| Procedural/events | `tests/chapter-13/13.4.4--fork-invalid.sv` | Accepted although the test metadata says only `fork...join_none` is permitted in a function |
| Assertions/SVA | `tests/chapter-16/16.2--cover.sv` | Compiler segfaults on a simple cover statement |
| Directives | `tests/chapter-22/22.11--pragma-invalid.sv` | Accepted although the test expects an invalid pragma form to be rejected |
| Directives | `tests/chapter-22/22.12--line-illegal-1.sv` | Accepted although the test says the `line` level must be 0, 1, or 2 |
| Directives | `tests/chapter-22/22.5.1--define-expansion_21.sv` | Accepted although macro text is split across string literals |
| Expressions/types | `tests/chapter-6/6.19.4--enum_numerical_expr_no_cast.sv` | Accepted although the test expects an enum numerical-expression rejection |
| Expressions/types | `tests/chapter-6/6.20.5--specparam_inv.sv` | Accepted with a warning although the test marks the `specparam` use invalid |
