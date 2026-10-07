# Indexed outer unpacked-struct constraints

Date: 2026-10-07

Branch: `agent/ieee-cross-object-solve-before-20261007`

## Reproducer and behavior

`ivtest/ivltests/sv_constraint_indexed_outer_struct.sv` constrains scalar
random members nested inside fixed arrays of unpacked structs. It checks a
descending 1-D range, a 2-D range, foreach-unrolled indices, non-random state
reads, enum-valued random/state leaves, and transactional rollback after an
unsatisfiable `randomize()` call.

The minimal pre-fix reproducer failed compilation in both strict editions with
four diagnostics of the form:

```text
sorry: constraint reference 'leaves[...].value' selects an indexed outer unpacked-struct property; indexed outer struct constraint paths are not supported.
```

The new lowering encodes the selected fixed-array storage word in the existing
class/member path. At runtime VVP resolves the selected struct object and
interns its terminal member into the canonical randomization graph, so random
leaves, state reads, writeback, and rollback use the existing solver path.

## Validation

From `iverilog-uvm/`:

```sh
make -j4
make install
```

From `iverilog-uvm/ivtest/`:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-constraint-indexed-outer-struct-legacy.list
PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-constraint-indexed-outer-struct-vvp.list
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-constraint-nested-struct-legacy.list
PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-constraint-nested-struct-vvp.list
```

Results: the new strict 2017/2023 cases pass **2/2** in each harness. The
adjacent nested-struct cases pass **2/2** in each harness. `git diff --check`
passes. No broad regression suite or OpenTitan corpus was run.

Installed binary SHA-256:

```text
iverilog f646fa5eaaf615b89fdd508c60ac4bff6a38e795197b76100b7da6c8fcdd0aa7
vvp      6fcc6f8da122cf0a8bf045897a02306968098ee7fbd6339a3e82f6646bc06a26
```

## Boundary

This qualifies fixed arrays of unpacked structs when indices are compile-time
constants or become constants through foreach unrolling, with scalar integral
or enum leaves along unpacked-struct member paths. Symbolic random indices,
dynamic arrays, queues, associative arrays, aggregate leaves, class-handle
members, and other clause-18 interactions remain open. This is one increment
toward the full IEEE 1800-2017/2023 objective, not a clause-18 closure claim.
