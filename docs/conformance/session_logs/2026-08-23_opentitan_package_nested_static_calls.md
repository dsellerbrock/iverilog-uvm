# OpenTitan package-qualified nested static calls (2026-08-23)

## Scope

The fresh OpenTitan matrix at revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` stopped 20 records (ten
cores repeated in the UVM and runtime lanes) on this legal UVM call in
`xbar_error_test.sv`:

```systemverilog
cip_base_pkg::cip_tl_seq_item::type_id::set_type_override(
    xbar_seq_err_item::get_type());
```

IEEE 1800-2017 8.23 permits static class-member access through class scope,
and 26.3 permits explicit package qualification. The equivalent unqualified
`cip_tl_seq_item::type_id::set_type_override(...)` form already parsed.

## Root cause and implementation

In statement position the lexer/parser deliberately reduces the common
`package::class::nested` prefix through `package_scoped_lvalue`. That carrier
ended after the nested name, so a following `::method(...)` entered recovery.
In expression position, `package_type_identifier` retained the package and
class specialization but had no production for the additional nested scope
and static function call.

The grammar now uses two context-specific continuations:

- expression calls extend `package_type_identifier` through the nested name,
  method name, and required argument parentheses to a `PECallFunction`;
- statement calls extend the already-reduced `package_scoped_lvalue` through
  the method, required parentheses, and trailing semicolon to a `PCallTask`.

Both paths retain the package, full class/typedef/method path, scoped-type
marker, and explicit class specialization. The statement action transfers
the carrier's parameter values with `take_leading_type_args()` before deleting
the carrier, so specializations keep independent static storage.

Putting a parallel rule in the generic `subroutine_call` grammar was rejected:
it added reduce/reduce conflicts. Duplicating the raw package prefix added two
shift/reduce conflicts. Including the statement's semicolon in
`statement_item` makes the choice deterministic.

## Parser and reduced-regression evidence

Parser generation used Homebrew Bison 3.8.2 with the Makefile flags. Apple's
`/usr/bin/bison` is version 2.3 and cannot generate this grammar.

- pristine `d08a1c4f6`: 535 shift/reduce, 1115 reduce/reduce;
- patched grammar: 535 shift/reduce, 1115 reduce/reduce;
- both have 201 normalized conflict descriptors;
- both descriptor lists have SHA-256
  `b96fa4bf669e73f14ed8748e864e8b3f4cdfbdc61b45ec6d5cab66a7e6946bc8`.

`sv_package_nested_static_call` value-checks the exact OpenTitan spelling,
statement and expression calls, a nested typedef, explicit parameterized
class specializations, and independent specialization storage. Its negative
companion pins missing/extra argument diagnostics in both contexts.

```text
legacy focus: 2/2 pass
JSON focus:   2/2 pass
full legacy SystemVerilog manifest: 1778/1778 pass
full JSON compiler/VVP manifest:     845/845 pass
Slang 11 positive: accept with zero diagnostics
Slang 11 negative: reject both arity violations
```

## OpenTitan integration evidence

The active compiler was rebuilt and installed from this worktree. A fresh
FuseSoC build root replayed all ten affected cores in both UVM and runtime
lanes. All 20 former `xbar_error_test.sv:12` syntax/malformed-statement pairs
are absent.

The records are not claimed as passes: the compiler now reaches the next
independent blocker. Sixteen records stop on a missing standalone
`prim_clock_gating` dependency, while the four full-chip records reach a later
`chip_common_pkg.sv` syntax boundary. Each record has one hard error rather
than the former parser pair.

Durable result:
`evidence/opentitan-package-nested-static-arm64-20260823/all-xbar/opentitan-xbar-20.json`
(outside the repository worktree).

## Tool invocation gotchas

- FuseSoC is pinned to 2.4.5 in
  `evidence/arm64-tooling/opentitan-python313`.
- Invoke the logical venv Python path
  `opentitan-python313/bin/python`; resolving its symlink bypasses
  `pyvenv.cfg` and changes imports.
- Keep that environment first on `PATH` so generator `python3` shebangs use
  the same Python 3.13 environment.
- Pass the same interpreter through `--fusesoc-python` and use the active
  worktree's absolute `local-install/bin/iverilog`.
- Use a fresh build root. Generated FuseSoC launchers and native objects from
  another compiler or host must not be reused.
- The Apple Silicon resource runner supplies a 45-second per-process CPU
  guard and no RSS ceiling.

Representative focused invocation:

```sh
TOOL_ROOT=../evidence/arm64-tooling/opentitan-python313
PATH="$TOOL_ROOT/bin:$PWD/local-install/bin:/opt/homebrew/bin:$PATH" \
../evidence/arm64-tooling/resource-runner \
  "$TOOL_ROOT/bin/python" scripts/opentitan_matrix.py \
  --opentitan-root ../opentitan-upstream \
  --build-root ../evidence/opentitan-package-nested-static-arm64-20260823/build \
  --iverilog "$PWD/local-install/bin/iverilog" \
  --fusesoc "$TOOL_ROOT/bin/fusesoc" \
  --fusesoc-python "$TOOL_ROOT/bin/python" \
  --lane uvm --core lowrisc:dv:top_darjeeling_xbar_mbx_sim:0.1 \
  --jobs 1
```

OpenTitan sources remained unmodified and clean.
