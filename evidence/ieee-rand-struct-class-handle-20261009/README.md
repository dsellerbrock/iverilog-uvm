# Rand unpacked-struct class-handle member

## Scope

This is a bounded IEEE 1800-2017/2023 §18.4 and §18.6.2 increment for an
enabled class handle reached through a random unpacked-struct member. The
runtime joins the child object to the containing joint solve, retains alias
identity, discovers its callbacks and constraint-state function, and rolls
back child values and `randc` history after a failed solve. This does not
qualify other class-handle or container-valued struct members and does not
close issue #419.

The paired regression
[`sv_randomize_struct_class_handle_member.v`](../../ivtest/ivltests/sv_randomize_struct_class_handle_member.v)
checks two struct properties aliasing one child, child and parent constraints,
the child's constraint function, one callback pair, failed-solve rollback,
and successful retry. The `-g2023` source includes the same test body.

## Local build and focused checks

The source-built ARM64 Icarus image reports `13.0 (devel) (9bd5082b8)`.
After the runtime changes, the local build/install completed with:

```sh
make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex
make install
```

From `ivtest/`, the new strict paired tests pass:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-randomize-struct-class-handle-legacy.list
# Total=2, Passed=2, Failed=0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-randomize-struct-class-handle-vvp.list
# Ran 2, Failed 0
```

Adjacent checks:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-constraint-nested-struct-legacy.list
# Total=2, Passed=2, Failed=0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-constraint-nested-struct-vvp.list
# Ran 2, Failed 0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-svtests-class-decls-focus-vvp.list
# Ran 14, Failed 0

PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-svtests-class-decls-focus-legacy.list
# Total=15, Passed=15, Failed=0
```

The declaration/member legacy focus had a stale compile-error classification
for the existing positive `sv_struct_member_constraint_fail` source and gold.
Changing that list entry to `normal` restores the intended 15/15 pass. Both
declaration/member and nested-struct neighbors pass; no broad suite was run.

The installed image hashes are:

| File | SHA-256 |
|---|---|
| `local-install/bin/iverilog` | `dadc5c7d23b1d5f4d5746dcf84a2cc404c70d8e9ca6655abc53b601f24f66da6` |
| `local-install/lib/ivl/ivl` | `90bd677ffb3452bb5b94164b9964cdc0d909a7a4edb61fcd392865e3f733211d` |
| `local-install/bin/vvp` | `9e45fe181fac2825ea652838aefcfead1e31e09f88f756602863688ce2b1ad3e` |
| `local-install/lib/ivl/vvp.tgt` | `06e10bff454b294e89afed01693e94b874ad69dc8a124788cb695aaefa2171a0` |

Draft PR [#527](https://github.com/dsellerbrock/iverilog-uvm/pull/527) carries
this increment. No CI status was queried, and no CI qualification is claimed.
