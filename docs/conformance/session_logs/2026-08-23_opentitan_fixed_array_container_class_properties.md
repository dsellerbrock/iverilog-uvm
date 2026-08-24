# OpenTitan fixed-array container class properties (2026-08-23)

## Scope and source witnesses

This change implements the direct non-static instance-class-property form in
which one or more fixed unpacked dimensions precede a queue or associative
array leaf. Representative legal declarations in the unmodified OpenTitan
source tree include:

```systemverilog
dma_intr_pred_t exp_intr_queue[NUM_MAX_INTERRUPTS][$];
local pattgen_item exp_item_q[NUM_PATTGEN_CHANNELS][$];
byte unsigned exp_data[NumBuffers][$];
bit_toggle_cg_wrap intr_ctrl_en_cov_objs[NUM_GPIOS][string];
```

The same source inventory uses typedef-named queues, queues of class handles,
queues of unpacked structs, multidimensional fixed prefixes, and string-keyed
associative leaves. The implementation is runtime-verified in permanent
reducers and both complete ivtest manifests. The final OpenTitan replay proves
that the former array-of-queue rejection is gone, but it reaches later,
independent compile blockers; this record therefore does not claim an
OpenTitan UVM or runtime pass.

The relevant IEEE 1800-2017/2023 rules are the fixed unpacked-array rules in
7.4, associative arrays and their methods in 7.8 and 7.9, queues and their
methods in 7.10, array/assignment compatibility in 7.6 and 10.8, and
per-object data properties in 8.5. The locally supplied IEEE 1800-2023 PDF was
consulted from `docs/standards/local/`; that directory remains intentionally
ignored and the copyrighted PDF is not part of the change.

## Defect and storage distinction

Type elaboration previously rejected every fixed unpacked array with a queue
leaf using the same `array of queue type is not yet supported` diagnostic.
That check ran before the compiler knew whether the value would use a class
instance's property storage or signal-backed storage.

The VVP class-property representation already has an array-sized object
property capable of constructing one queue or associative-array object in
every fixed slot. The implementation now preserves a queue/map leaf through
fixed-array type elaboration and admits that representation for a direct
non-static instance property. Signal-backed declarations are diagnosed after
their storage kind is known; they are not allowed to fall into a backend that
cannot allocate an independent container per word.

The frontend and target also keep the two index domains separate:

```text
object.property[fixed prefix][queue position or associative key][packed select]
                ^ property slot ^ selected container element    ^ element bits
```

The fixed prefix is canonicalized in declared-index order into the property
slot. Each trailing queue position or associative key becomes a nested
container select. This prevents an inner key from replacing the outer slot
index and prevents every operation from silently targeting slot zero.

## Implemented semantics

The source-reviewed implementation covers these direct instance-property
semantics:

- ascending, descending, nonzero-based, negative-based, and multidimensional
  fixed prefixes, with independent container state in every selected slot;
- positional queues and associative arrays, including a typedef-named queue
  leaf and string/integral associative keys;
- whole selected-leaf assignment with container value-copy semantics, including
  enforcement of a selected bounded queue's declared maximum and direct
  fixed-array-to-queue-property assignment in declared order;
- whole fixed-outer property assignment decomposed into declared-order slot
  assignments, with an independent value copy of every queue/map leaf;
- positional element and associative-key reads/writes for integral, real,
  string, class-handle, unpacked-struct, and nested-container values;
- class-handle identity and value copying for aggregate/container elements;
- recursive value-copy and receiver typing through arbitrary trailing
  queue/associative/dynamic-array chains, including selected nested dynamic-
  array `delete()`;
- contextual conversion of associative keys and integral leaf values to their
  declared key width, signedness, state domain, and element width;
- associative vivification that inserts a nil dynamic-array value rather than
  manufacturing a queue, and root change notification that survives later
  mutations through the selected child receiver;
- `size`, `num`, `exists`, `delete`, `push_front`, `push_back`, `insert`,
  `pop_front`, and `pop_back` on a fully selected leaf, using the existing
  typed queue/associative method paths;
- queue slices as r-values, packed bit/part/indexed selects on integral
  elements as r-values and l-values, and member/method traversal after a
  selected class or unpacked-struct element;
- `$` as the last positional queue element in vec4, real, string, and object
  expression/method-receiver paths without evaluating the queue receiver a
  second time; and
- one evaluation of the fixed-prefix expression and selected queue receiver
  along the staged property-selection paths.

An undefined, negative-after-canonicalization, or out-of-range fixed-prefix
index cannot alias a valid slot. A read yields the selected leaf's empty/null
default path; a write or mutator is a warned no-op. The class runtime's final
defensive accessor likewise returns null or ignores the store instead of
falling back to slot zero. Queue `delete(index)` also treats any X/Z state as
invalid and the object-receiver path consumes its receiver on every rejected
index, preserving VVP stack discipline.

The same checked-slot rule applies before a trailing container is selected:
scalar integral/bit, real, string, class-handle and unpacked-struct properties
behind a fixed prefix return their type-appropriate default on an invalid read
and ignore invalid writes. This includes packed read-modify-write selections.
Each raw multidimensional index and each right-hand side is evaluated exactly
once, including the invalid path.

## Loud and unclaimed boundaries

This is a deliberately partial implementation. The following shapes remain
loud:

- module/package/interface signals and static class properties whose type has
  a fixed unpacked prefix above a queue or associative-array leaf, including a
  lazily materialized parameterized-class static property;
- a fixed array of queues/maps nested inside an unpacked-struct class property;
  only the direct property shape is admitted;
- a direct fixed array of dynamic-array leaves, which retains the pre-existing
  type-elaboration `sorry`;
- reading the complete fixed outer property as one aggregate r-value; whole
  outer assignment is implemented by per-slot decomposition, and selecting
  and assigning one inner container is also supported;
- assignment to a queue slice through the selected object-backed property
  slot, and `$` last-element selection as an l-value;
- calling a resizable-container method before supplying every fixed-prefix
  index;
- direct member/container selection from a function-call result, such as
  `get_holder().mem[i]`; storing the returned handle before property access is
  the supported form;
- packed or compound assignment to a whole selected container; and
- member insertion through an object-keyed associative array whose values are
  unpacked structs.

No closure is claimed here for class-property container-element `ref`
lifetime, randomization/constraints, VPI enumeration of this composite shape,
or synthesis. Those dimensions require their own evidence even when ordinary
simulation lowering is correct.

## Permanent reducers staged with the implementation

`sv_class_fixed_array_container_property` exercises fixed-prefix direction and
independence, whole-inner value copy, r-value slices, a function-returned
handle stored before property access, real/string/object/nested-container
values, associative methods and struct-member materialization, last-element
reads/method calls, and inner container deletion.

`sv_class_fixed_array_container_packed_select_oob` stages the packed bit/part/
indexed-select and invalid fixed-prefix oracles.
`sv_class_fixed_array_container_outer_assignment` stages whole-outer per-slot
value-copy and post-assignment source/destination independence.

`sv_class_fixed_array_scalar_index_oob` pins invalid checked-slot behavior for
integral/bit, real, string, class-handle and unpacked-struct properties,
including packed read-modify-write, X/Z, wide-unsigned and constant-OOB
indices, cancellation cases, and exactly-once index/RHS evaluation.
`sv_class_fixed_array_deep_container` exercises fixed-to-queue-to-queue-to-
queue, fixed-to-associative-to-queue-to-associative, and fixed-to-associative-
to-queue-to-dynamic-array chains for string and class values. It pins
source/read value copies, invalid dynamic positions, fixed-prefix invalidity,
selected nested dynamic-array deletion, and valid operations after each
rejected access.

`sv_nested_container_audit` pins the adjacent runtime contracts needed by the
property lowering: typed associative keys and leaves, insertion and child-
mutation notification, associative-of-dynamic-array nil vivification, bounded
queue leaves under positional and associative chains, and independent value
copies. It also assigns a descending bare fixed array into both a scalar and a
selected fixed-array bounded queue property, then uses queue mutators to prove
the runtime object is a queue rather than a dynamic-array lookalike.

The focused negative sources pin incomplete fixed prefixes, static and other
signal-backed declarations, a struct-nested property, whole-outer r-value
materialization, and the queue-slice l-value boundary. The invalid-delete
reducer pins X/Z and negative queue-index handling without receiver-stack
corruption.

## Final ARM64 evidence

### Provenance and build

- The feature branch and the fetched `origin/main` both started at
  `89dd18f62eb2aac938afa095ab37320ea752b622` (merged PR #211). A final fetch
  immediately before packaging showed that `origin/main` had not moved.
- The unmodified OpenTitan checkout was clean at
  `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` before and after every replay.
- One coordinated native ARM64 build was installed under `local-install`.
  `make -j1 check` passed, including both Hello World engine/driver checks,
  and `make -C tgt-fpga -j1` was clean.
- Final installed fingerprints were:
  `iverilog=e096028674a62bf739a3f196c5cf4dc5de15dfb86662b48bc5648c912ad3677a`,
  `ivl=3e4686dedf3a2d034a85d35df03bae571be23f292b30933cb12701a25fc38daa`,
  `vvp.tgt=8aeb9161fe01458814edd2cc71487b4077f3612ff491aafc23fb286f44e17386`,
  and
  `vvp=cd2be1104a50eaa6d3002559e79b5fbd9c727fa35cc270b88195b209613f5ab9`.

### Focused, differential, and regression checks

- The new focused legacy manifest passed 15/15 and the split JSON/VVP
  manifest passed 15/15 against the coordinated install. Positive runtime,
  invalid-index, value-copy, bounded-queue, and all loud negative boundaries
  matched their checked-in gold files exactly.
- A combined regression focus containing every initially exposed adjacent
  failure passed 9/9. The initial full gate had found three semantic target
  regressions, five bounded-queue warning-path changes, and one lost secondary
  frontend diagnostic. The fixes restore the established behavior and exact
  diagnostics; no pre-existing gold file was changed.
- Full legacy `regress-sv.list`: **1,792/1,792 passed**, zero failures,
  59.35 seconds, peak RSS 912,769,024 bytes. The still broader default legacy
  gate also completed 3,976 records with zero failures (3,971 passes, two
  not-implemented records, and three expected failures).
- Full split `regress-vvp.list`: **860/860 passed**, zero failures,
  14.52 seconds, peak RSS 68,993,024 bytes.
- No RSS ceiling was applied. A 10,000-iteration nested bounded-container copy
  reducer passed in 1.90 seconds at 6,373,376 bytes peak RSS, so the value-copy
  path shows no transient-copy accumulation or leak.
- The checked multidimensional-index reducer compiled and ran cleanly. It pins
  the former cancellation-to-a-valid-flat-slot case, X/Z and wide-unsigned
  indices, invalid reads/writes/mutators, and exactly-once left-to-right
  evaluation of every dimension. Legacy object-queue bytecode spellings also
  parse and run with the new bounded aliases present.
- Slang `11.0.448+e222e7dc0` completed 20/20 clean checks under both
  IEEE 1800-2017 and 1800-2023 across the positive property/audit sources and
  three G09 nested-container sources. The packed and scalar OOB oracles were
  checked with only the expected index-OOB warning disabled.

### Final OpenTitan witness replay

The exact 14-record replay used OpenTitan's ARM64 Python 3.13 environment,
FuseSoC 2.4.5, and the unmodified source checkout. It retained the 45-second
per-process CPU guard but had no RSS limit. Evidence is in
`evidence/opentitan-fixed-array-containers-final3-arm64-14record-20260823T2347MDT/`
outside this worktree:

- `result.json` SHA-256
  `c61381516b4ac581da193a81cf8826f5f3935e77d7fe6657b318635b6ad19d70`;
- `result.md` SHA-256
  `d02cb8660573fad80325f6f344358d514381e05ff8e2cab9989c58e45faba3ec`.

All seven selected cores classify `FAIL` in both UVM and runtime lanes because
each lane stops at compilation; no runtime is launched. The former
`array of queue type is not yet supported` diagnostic occurs zero times. The
new first blockers are:

- Darjeeling, Earlgrey, and English Breakfast GPIO: `find()` on a fixed-array
  class property;
- DMA: unresolved inherited `post_randomize` and unpacked range slices;
- I2C: illegal/ignore transition bins, queue-property `$` selects, and
  constrained `std::randomize` container operands;
- Pattgen: virtual-interface `apply_reset`/`drive_rst_pin` argument-row
  lookup; and
- USBDEV: hierarchical enum/variable constant expressions, variable part
  selects, and constrained `std::randomize` container operands.

There were no setup/compile timeouts or CPU-limit kills. The result is
specifically a verified removal of G74's former blocker and identification of
the next independent frontiers, not an OpenTitan pass claim.
