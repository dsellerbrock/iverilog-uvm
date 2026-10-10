# IEEE 1800 packed symbolic nested select — 2026-10-09

## Scope

Issue [#421](https://github.com/dsellerbrock/iverilog-uvm/issues/421) remains
open. This change covers a bounded class-constraint shape: a symbolic index
into a one-dimensional packed array of packed structs, followed by one or more
unindexed packed-struct member reads. It does not qualify all packed-select
randomization forms.

The local IEEE 1800-2017 and 1800-2023 copies were checked at §§7.4.1, 11.5.1,
and 18.3. Section 7.4.1 defines packed arrays as vector subfields. Section
11.5.1 permits an expression as a self-determined bit-select address and
defines invalid reads as X for four-state values and 0 for two-state values.
Section 18.3 uses selected packed bits in a constraint and requires a solution
when one exists. The relevant wording is materially equivalent in both
editions. The nested array-of-struct form is the combined application of these
rules; it is not an example printed verbatim in §18.3.

## Reproducer and implementation

On fresh `origin/main` at `c339b9f2287a743aeb7ab6de6528e8d34a4dd602`, a class
constraint on `holder.words[index].value` warned that the item was not
representable and made `randomize()` fail under both `-g2017` and `-g2023`.

The class-constraint path now admits symbolic selection only for a
one-dimensional packed array whose element type is a packed struct. It reuses
the typed packed-element selection IR, then extracts the remaining packed
member offsets from the selected element. A four-state out-of-range selection
still fails at runtime; index 2 is the paired boundary control for the declared
`[1:0]` array.

## Tests and local results

The self-authored paired fixture checks that indices 0 and 1 constrain the
selected member to `2'b10`, and that index 2 makes `randomize()` fail. It is
registered in the legacy `regress-sv.list` and JSON/VVP `regress-vvp.list`.
The older `sv_constraint_packed_parray_select` JSON pair also passes: constant
element constraints remain exact and its symbolic out-of-range read now emits
the precise four-state invalid-index runtime diagnostic instead of an
elaboration-time unsupported-item warning.

From `ivtest/`, using the branch-local `local-install/bin` first in `PATH`:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-packed-struct-symbolic-select-legacy.list
PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-packed-struct-symbolic-select-vvp.list
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl --strict regress-packed-struct-symbolic-select-legacy.list
PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py --strict regress-packed-struct-symbolic-select-vvp.list
```

Results: legacy 2/2 and JSON/VVP 4/4 in both ordinary and strict-expression-
width modes. `make -j1 YACC=/opt/homebrew/opt/bison/bin/bison
LEX=/usr/bin/flex` and `make install` also succeeded on the local macOS build.
No full repository suite or CI checks were run.

## Remaining boundary

Multidimensional packed arrays, packed selections through additional indexed
member paths, other packed base shapes, and broad clause qualification remain
open. Do not infer full §18 conformance from this bounded result.
