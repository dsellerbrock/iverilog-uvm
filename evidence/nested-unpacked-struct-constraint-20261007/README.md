# Nested unpacked-struct constraint leaves

## Scope

IEEE 1800-2017/2023 §18.4/§18.5: a constraint may reach a scalar integral or
enum random leaf through a finite chain of unpacked-struct members rooted at a
randomized class property. The implementation uses the existing runtime path
representation and preserves nested `rand`/`randc` activation, non-random state
reads, solver identity, writeback, and failed-solve rollback.

The permanent regression is
[`sv_constraint_nested_unpacked_struct.sv`](../../ivtest/ivltests/sv_constraint_nested_unpacked_struct.sv).
It checks a two-level nested struct path, integral and enum constraints,
`randc` history, state-derived values, contradiction rollback, and resumption.

## RED baseline

On pre-fix `04093c40e`, the paired 2017/2023 reproducer failed elaboration with
the unsupported unpacked-struct constraint-path diagnostic. The existing
negative case also rejected `record.nested.scalar`; this case is now a positive
regression, while indexed outer-struct paths remain compile-time errors.

## Build and GREEN checks

The successful source build used the installed ARM64 Homebrew Z3 and libffi
prefixes:

```sh
./configure --enable-libveriuser --prefix="$(pwd)/local-install" \
  YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex \
  CPPFLAGS="-I/opt/homebrew/opt/z3/include -I/opt/homebrew/opt/libffi/include" \
  LDFLAGS="-L/opt/homebrew/opt/z3/lib -L/opt/homebrew/opt/libffi/lib"
make -j4
make install
```

From `ivtest/`, the strict paired checks passed:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-constraint-nested-struct-legacy.list
# Total=2, Passed=2, Failed=0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-constraint-nested-struct-vvp.list
# Ran 2, Failed 0

PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-svtests-class-decls-focus-legacy.list
# Total=15, Passed=15, Failed=0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-svtests-class-decls-focus-vvp.list
# Ran 14, Failed 0
```

The adjacent lists include existing one-level struct-member constraints,
member arrays, `randc` rollback, and the compile-negative indexed outer-struct
control. No broad suite or application corpus was run for this blocker.

## Source-built image

Icarus reports version `13.0 (devel) (9bd5082b8)`. SHA-256:

| File | SHA-256 |
|---|---|
| `local-install/bin/iverilog` | `9fff8e65fdf17051bb3f78b445304d705688495c251eaf7f7f31920e6935dbcc` |
| `local-install/lib/ivl/ivl` | `61fd48936309d80a6535df595b73ab1901dfa38018a68a40e8ea3078555079b6` |
| `local-install/bin/vvp` | `3bfcc5dc8918a4a0d3be40daea917d28379e72096304e1af9322a8d8911a4da8` |
| `local-install/lib/ivl/vvp.tgt` | `404a3620fc341d4746a77d7f89086505ccbbf35a7a95832b896ab32b3138dfb1` |

## Limits

Indexed outer structs, array/container-valued leaves, and class-handle members
remain unsupported. This closes only the tested scalar integral/enum path
subset; it does not qualify all of clause 18.
