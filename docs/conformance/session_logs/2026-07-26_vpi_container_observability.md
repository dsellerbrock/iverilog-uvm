# 2026-07-26 — VPI runtime-container observability

## Starting point and selection

This campaign started from the head of
`codex/access-aggregate-boundary-closure` (PR #122, commit `0b81870d9`).
PR #122 merged during the campaign, and the publication branch was
fast-forwarded to its merge commit (`d0d51c226`). The next priority
frontier was the SystemVerilog VPI boundary for runtime containers stored
in class properties, together with `cbValueChange` on runtime-container
elements. The existing direct-container read surface was not sufficient
evidence: the campaign required declaration metadata, live access,
mutation, lifetime and callback behavior.

Two permanent tests were written before the fix and run against the
starting build:

- `m12_container_props` produced 36 deterministic failures. A queue
  property reported size zero and yielded no members; a dynamic-array
  property reported as a 64-bit `vpiClassVar`; an associative array
  reported the wrong array kind; every requested element handle was null;
  nested, string and real property containers were absent; VPI writes did
  not reach SV; and saved member handles did not follow object replacement
  or growth.
- `m12_container_cb` produced three deterministic failures. In particular,
  the class-property element handle was null, while a callback that did
  register on a direct runtime-container word fired zero times.

These failures were stable across repeated runs and distinguish missing
behavior from a test that merely reaches `$finish`.

## Root causes

Five independent layers contributed:

1. `__vpiClassMember` exposed a property's static scalar/object metadata.
   Queue/associative tags existed, but the handle did not adapt to the
   live runtime container, so size, iteration, index lookup and element
   access all stopped at the member boundary.
2. Dynamic-array class properties were emitted as the generic object tag
   `"o"`. A null or empty value therefore carried no declaration evidence
   that could distinguish it from a class handle.
3. Runtime-container word callback registration entered the static-array
   path and `static_cast` its `__vpiArrayBase` parent to `__vpiArray`.
   The callback was consequently attached to storage that did not own the
   runtime value.
4. Associative-array property stores and deletes mutated the associative
   object without publishing a mutation notification to the class root.
5. A class root may own several runtime containers. Attaching all property
   callbacks to that root is necessary for live replacement, but an
   unfiltered root notification would fire callbacks for unchanged
   siblings.

The saved-handle test exposed one additional lifetime requirement:
runtime word-handle caches must grow without invalidating handles returned
before the owner or container grew.

## Implementation

The compiler now emits a distinct dynamic-array property descriptor:
`D` plus the element kind, signedness and packed width. The runtime keeps
the same object-backed storage, while retaining enough declaration
metadata to report a dynamic array even when its value is null.

`__vpiClassMember` now reuses the runtime-array handle surface. It resolves
the current member value on every operation and reports:

- `vpiArrayVar` plus queue/dynamic/associative `vpiArrayType`;
- live `vpiSize`;
- `vpiMember`/word iteration and `vpi_handle_by_index`;
- natural integral, string and real reads and writes;
- nested paths and a root scope;
- live behavior after an intermediate owner is replaced.

The word-handle cache grows by allocating a new simulator-lifetime block.
Earlier blocks are retained so an already-returned VPI handle continues
to represent its positional index through the same live parent.

Runtime word callbacks now ask the array parent for its owning signal
functor rather than assuming a static array. Direct containers attach to
their signal; class-property containers attach to the root object signal.
Each callback snapshots its own element in a natural representation
(binary text, string, real, or suppressed). A root notification dispatches
only if that element's snapshot changed, which filters mutations to sibling
containers. SV associative stores/deletes publish root notifications, and
VPI element writes dispatch callbacks after the value is stored.

The supported mutation boundary is deliberately element-level. A VPI
write to an entire runtime-container class property remains a loud
unsupported operation rather than an accepted no-op.

## Permanent coverage and anti-vacuity

`ivtest/vpi/m12_container_props.{v,c}` covers:

- direct and nested class-property paths;
- int queue, dynamic array and string-keyed associative array;
- string queue and real dynamic array;
- populated, empty and null values;
- declaration kind, live size, iteration count and indexed reads;
- typed VPI writes observed back in SystemVerilog;
- saved queue/dynamic/associative member handles across owner replacement,
  growth from two to three elements, and access to the newly added word.

`ivtest/vpi/m12_container_cb.{v,c}` covers direct queue/associative words
and class-property queue/dynamic/associative/string/real words. Every
callback must fire exactly twice: once for an SV write and once for a VPI
write. The gold log fixes the exact immediate order and values. Exact
counts prove that shared-root notifications do not create sibling
callbacks; final values prove the second event is not a replay of the
first.

Both tests are registered in `ivtest/vpi_regress.list` with permanent gold
logs.

## Validation

Final results:

- clean parallel build and staged local install;
- focused property/callback tests: pass;
- `make check`: pass;
- negative diagnostics: 61/61;
- SVA legacy/NFA dual-run: 36/36;
- vendored ivtest name-diff: 3,217 total, exactly 44 expected failures,
  zero unexplained or stale failure identities;
- bundled VPI: 94/94;
- dedicated DPI subsystem: 20/20, real DPI umbrella, zero skips;
- full UVM: 226/226, real DPI umbrella, zero skips;
- staged, relocated installed `-uvm` frontend: all eight scenarios pass.

The targeted UVM helper itself exposed a macOS portability defect:
`mapfile` is unavailable in Bash 3.2, which left duplicate names and noisy
`ln` failures even though the unique tests ran. Its de-duplication now uses
Bash 3.2-compatible array accumulation; the clean rerun selected exactly
20 DPI tests.

The status remains **substantial**, not FULL. This campaign closes the
runtime-container class-property and element-callback frontier only.
