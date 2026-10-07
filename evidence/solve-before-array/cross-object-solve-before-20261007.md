# Cross-object `solve before` — 2026-10-07

## Result

Fix 28 admits a nested class-property `r:` path as a `solve before` operand and
retains its canonical random-variable identity in the existing VVP object
graph. The paired strict 2017/2023 checks pass. This closes the tested nested
scalar case only; Z01 remains partial.

## Reproducer

`ivtest/ivltests/sv_constraint_cross_object_solve_before.v` constrains a
parent's two-bit `b` by the value of `rand Child child`'s `rand bit a`:

```systemverilog
constraint relation_c { b inside {[0:(child.a ? 2'd3 : 2'd1)]}; }
constraint order_c { solve child.a before b; }
```

With `a` solved first, the expected staged sample has two legal `b` values for
`a==0` and four for `a==1`; over 2,000 draws the test checks each first-group
tuple in `[425,575]` and each second-group tuple in `[190,310]`. A simultaneous
uniform draw over the six legal pairs would fail the first group bounds. The
test also makes the solve unsatisfiable and verifies that failed randomization
leaves both random properties unchanged.

Before the fix, the compiler warned that the nested ordering operand was not
representable and randomization failed with malformed class-constraint
capture. The same value constraints without the ordering clause solved. The
root cause was that expression lowering already emitted an `r:` object path,
but `PEConstraintOrder` rejected that token before the runtime could use the
object graph's canonical leaf identity.

## Qualification

Source-built ARM64 image:

- `iverilog`: `1e80ff0dad9a2fe60a4885a6d540ae8fe77a743bd8f42d359b26247b1b786a50`
- `ivl`: `f569461592063ae8df49c7f9a891c5e43ec1b03ffe1e0378e3d8f9e9ec044c50`
- `vvp`: `1d2955a4d7e886608a8f343401619940e1b3adf52bafc66b5eb13d58db9d32b5`
- `vvp.tgt`: `dcdf2a5a5aeef3422952a7ff61ad874cb577beacf120e27b9244d9dd599c7243`

From `ivtest/`:

```sh
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  python3 vvp_reg.py --strict regress-cross-object-solve-before-vvp.list
```

Result: **6/6 passed**, including both editions of the new statistical case,
fixed-array ordering controls, and fixed-array/randc rejection controls.

```sh
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  perl vvp_reg.pl --strict regress-cross-object-solve-before-legacy.list
```

Result: **6/6 passed**, with the same controls. No broad suite or OpenTitan
corpus was run for this focused increment.

## Remaining Z01 scope

Other hierarchical path shapes, aggregate and selected-element ordering,
ordered `dist`, additional randc interactions, and solver domains that exceed
the existing exact-work limits remain open. The change does not expand the
full clause-18 conformance claim or alter the 49/49 OpenTitan acceptance.
