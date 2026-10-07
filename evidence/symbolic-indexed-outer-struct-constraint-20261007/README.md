# Symbolic indexed outer-struct constraints

Date: 2026-10-07

Branch: `agent/ieee-cross-object-solve-before-20261007`

## Scope

Fix 37 extends the fixed-array-of-unpacked-struct constraint path from
constant and foreach-unrolled selectors to symbolic integral selectors. It
lowers the selected scalar leaf to guarded choices over the array's flat
storage words. The tested active-random selector is 2 bits and constrained to
the declared indices `{1, 2}`. A state-read control selects a known leaf while
the unselected leaf contains X.

Only scalar integral and enum leaves are covered. Symbolic expansion is
limited to fixed arrays of at most 65,536 words. This does not qualify dynamic
containers, aggregate/class-handle leaves, uniformity, or wide coupled-domain
sampling.

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

The indexed-struct lists pass **2/2** in each harness. The adjacent
nested-struct lists pass **2/2** in each harness. `git diff --check` passes.
No broad regression suite or OpenTitan corpus was run.

Installed binary SHA-256:

```text
iverilog f646fa5eaaf615b89fdd508c60ac4bff6a38e795197b76100b7da6c8fcdd0aa7
vvp      da3ecdef09ef8bf415465b203eeffa076bc68423a39c3cfa39888efd2791872c
```

## Reproducer

`ivtest/ivltests/sv_constraint_indexed_outer_struct.sv` is the minimal paired
2017/2023 fixture. Before Fix 36, indexed outer-struct paths were rejected;
Fix 36 added constant and foreach-unrolled selectors. The symbolic case now
checks that the randomized selected value equals the value of the selected
struct leaf, and that an unselected X state leaf does not fail the solve.
