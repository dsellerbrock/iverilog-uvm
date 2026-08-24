# OpenTitan fixed-array class-property locators (2026-08-24)

## Scope and standard rule

OpenTitan GPIO uses a one-dimensional fixed unpacked array as a non-static
class property and filters it with `find()`:

```systemverilog
tmp_q = stable_cycles_per_pin.find(m) with (m != FILTER_CYCLES);
```

IEEE 1800-2023 7.12.1 applies locator methods to every unpacked array. Locator
traversal order is unspecified, while `find_first*` and `find_last*` mean the
matching element closest to the leftmost and rightmost declared index,
respectively. Index-returning methods return `int` indices for a fixed array.

The prior compiler stopped with:

```text
sorry: find() on a fixed-size array class property is not yet implemented.
```

Slang 11.0.448 accepts the permanent positive source under both
IEEE 1800-2017 and IEEE 1800-2023.

## Root cause and implementation

The common locator loop indexes a signal label. A fixed-array class property
is inline object storage and has neither that label nor a dynamic-container
handle, so `make_array_method_recv_net_()` deliberately rejected it.

The frontend now evaluates a supported one-dimensional fixed-property
receiver exactly once and materializes its complete value into a typed hidden
dynamic array. The locator payload also carries:

- a canonical storage index used to read the temporary;
- a distinct declared index visible to `item.index`/`item.index()` and every
  `*_index` result;
- the declared direction used to select the leftmost/rightmost match.

The target loop publishes the declared index before evaluating the predicate.
It supports integral, real, string, and class-handle property elements. Each
returned queue is fresh scalar/value storage; class elements retain ordinary
handle-copy semantics. Existing direct fixed-signal lowering is unchanged.

## Permanent coverage

`sv_array_locator_fixed_property` proves:

- the reduced OpenTitan GPIO `find()` form;
- all six locator methods;
- zero, nonzero, and negative declared index bases;
- descending leftmost/rightmost behavior;
- iterator index queries and `*_index` result values;
- bit/logic, real, string, and class-handle elements;
- an exactly-once side-effecting receiver base;
- fresh scalar result snapshots and empty results.

`sv_array_locator_fixed_property_fail` retains a focused diagnostic for the
still-unimplemented multidimensional property receiver. The older
`sv_array_find_last_fixed_shape_fail` continues to pin multidimensional direct
arrays and direct fixed arrays of nonintegral elements. Both legacy and JSON
focus lists contain the positive, the residual negative, and adjacent direct
fixed locator/reduction/unique coverage.

## Validation and OpenTitan witness

- focused legacy: 7/7;
- focused JSON/VVP: 7/7;
- full `regress-sv.list`: 1,794/1,794;
- full `regress-vvp.list`: 862 records, zero failures;
- affected objects are current and `git diff --check` is clean.

The unmodified OpenTitan checkout was pinned at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`. Recompiling the generated
`lowrisc:earlgrey:dv:gpio_sim:0.1` input with the worktree's ARM64 Icarus
returns zero and contains no fixed-property locator diagnostic. It still emits
the previously triaged virtual-interface argument-row diagnostics and other
compile-progress warnings, so this is a verified removal of the GPIO blocker,
not a UVM runtime or whole-design semantic-closure claim.

Workspace-root-relative evidence is in
`evidence/opentitan-fixed-property-find-arm64-20260824T0032MDT/`; its
`SUMMARY.md` SHA-256 is
`dcf72578e3655d287b99f41f24dabe92e01a920c56d73e4fd7dfad116dc0e000`.

## Remaining boundaries

Multidimensional fixed-property locators remain loud because their iterator
value is itself a subarray. Associative locator keyed traversal, aggregate
element value copying, direct fixed-signal nonzero-base/nonintegral receivers,
and result typing through arbitrary expression wrappers remain separate gaps.
