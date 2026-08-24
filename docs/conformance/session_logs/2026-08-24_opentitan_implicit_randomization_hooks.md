# OpenTitan implicit randomization hooks (2026-08-24)

## Scope and standard rule

IEEE 1800-2017/2023 18.6.2 implicitly declares these zero-argument `void`
functions for every class:

```systemverilog
function void pre_randomize();
function void post_randomize();
```

Their default bodies are empty. A class may override either hook, and an
override may call the inherited implicit body with `super.pre_randomize()` or
`super.post_randomize()` even when no ancestor contains an explicit source
declaration.

OpenTitan DMA contains that exact shape in `dma_seq_item.sv:491`. Its declared
`post_randomize()` calls `super.post_randomize()` through `uvm_sequence_item`,
whose hierarchy has no explicit declaration. Icarus previously emitted an
unknown-task error and then used its compile-progress fallback.

## Root cause and implementation

Statement-call elaboration only searched installed class method scopes. A
legitimate miss for either standard hook was therefore indistinguishable from
an ordinary unknown method.

The two method-call paths now recognize a genuine implicit hook only after the
receiver class hierarchy reports that its scopes are complete. They also scan
the parsed class declarations through the inheritance chain before supplying
the default body. This prevents an incomplete or otherwise unresolved user
declaration from being silently replaced.

The empty hook lowers through `$ivl_discard_object_expr`, so an arbitrary
receiver expression is still evaluated exactly once. An implicit hook with
arguments produces a local deterministic error. Declared hooks continue down
the existing method-resolution and dispatch path without special treatment.

## Permanent coverage

`sv_implicit_randomize_hooks` verifies:

- direct and implicit-`this` calls on an empty class;
- explicit `super` calls from declared overrides;
- automatic calls around `randomize()`;
- declared inherited hooks retain their bodies;
- arbitrary empty-hook and declared-hook receivers are each evaluated once.

`sv_implicit_randomize_hook_args_fail` pins three illegal nonzero-argument
forms: ordinary, explicit-`super`, and arbitrary receiver-expression calls.
Both tests are present in the legacy and JSON/VVP main manifests and in small
focus lists.

## Validation

The change was rebuilt natively on arm64 from merged `origin/main`
`fdccc7ec5bbfb6484ba7e5c10e70aa582ce4d784`. The installed `iverilog`, `vvp`,
and Homebrew Python binaries were all verified as Mach-O arm64. No compiler
RSS limit was used; downstream probes retained only the 45-second per-process
CPU runaway guard.

- new focus: legacy 2/2 and JSON/VVP 2/2;
- related legacy class/randomization/randc focuses: 65/65;
- related JSON/VVP focuses: 58/58;
- complete `regress-sv.list`: 1,796/1,796;
- complete `regress-vvp.list`: 864 records, zero failures;
- serial `make check`: passed;
- Slang 11.0.448: positive accepted under 1800-2017 and 1800-2023;
- Slang 11.0.448: negative rejected with exactly three errors under each
  standard mode.

The exact reduced DMA shape compiled and printed `PASSED`. The unmodified
frozen `lowrisc:dv:dma_sim:0.1` graph at OpenTitan commit
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` no longer reports either hook.
It advances to exactly two independent errors:

```text
dma_scoreboard.sv:1446: error: Array cannot be indexed by a range.
dma_scoreboard.sv:1450: error: Array cannot be indexed by a range.
```

No OpenTitan or Caliptra source was changed, and no DMA simulation ran. The
result proves removal of this compiler blocker rather than whole-design
closure.

Evidence is under
`evidence/opentitan-dma-implicit-hooks-fresh-arm64-validation-20260824T0054MDT/`.
`validation-summary.txt` has SHA-256
`3f90f7d73f559cf0c1831c4b22ee7327e18b5fdca1bf72f3678258c8a1f3285f`;
the `SHA256SUMS` manifest has SHA-256
`f2886e58ae1eb55c96ffbd69df06a2732bdcb79154e000b75352a63e55840e98`.

## Remaining boundaries

This increment supplies only the standard default bodies and preserves the
existing declared-hook behavior. It does not claim full clause-18 closure,
recursive child-object hook dispatch, or resolution of the two newly exposed
DMA fixed-array range-lvalue blockers.
