# Class instance constants and embedded-covergroup constructor order (2026-09-01)

## Scope and provenance

- Worktree: `iverilog-uvm-opentitan-instance-const-after247-arm64-20260830`
- Branch: `agent/opentitan-instance-const-after247-arm64-20260830`
- Base: `1a877231fef3f5579a5f406813c84fb34c316e60` (PR #247 merge)
- Standards: IEEE 1800-2017 and IEEE 1800-2023 clauses 8.19, 12.7.1,
  and 19.5
- Build: native ARM64, Homebrew Bison 3.8.x, serial `make`, every compiler,
  simulator, and corpus driver through the shared 45-second CPU guard with no
  RSS ceiling

The OpenTitan and Caliptra trees were not modified. Application evidence was
generated outside their source trees.

## Defects

Three mechanisms interacted:

1. A procedural `for` initializer was lowered only through the direct signal
   form used by `NetForLoop`. A class-property l-value could not take ordinary
   assignment typing/runtime enforcement, while a static const signal could
   bypass ordinary const-write legality.
2. The constructor-order audit treated several loops as one undifferentiated
   possibly-zero-trip region. It did not preserve the one-shot header, body to
   step `continue`, break/return exits, defined-false bodies, or safe zero/one
   repeat-count evidence with lexical shadowing.
3. Source authorization alone cannot enforce 8.19's dynamic “assigned only
   once” rule when two distinct authorized sites are conditionally or
   repeatedly reached by one object.

## Implementation

`PForStatement` now owns a stable ordinary `PAssign` carrier for its header
initializer while retaining the parsed operands needed by synthesis. A
mutable signal still lowers directly to `NetForLoop(index, initial_expr, ...)`.
A class property, other nonsignal l-value, or const signal instead elaborates
through ordinary assignment logic and is sequenced once before the loop.

The parse-form constructor audit now records path-sensitive normal, break,
continue, and return channels. A `for` header is outside its repeated region;
the body and step share that region. Omitted or direct defined-nonzero literal
conditions guarantee entry, a direct defined-zero literal skips body and step,
and other conditions keep the zero-trip and backedge alternatives. `continue`
feeds the step, while `break` and return bypass it.

Literal and already-evaluated class-parameter repeat counts are classified
without elaborating an expression, mutating the design, or emitting a
diagnostic. Locals, formals, explicit imports, and wildcard imports pinned by
ordinary lookup shadow the class parameter. A direct unary minus is applied
with `verinum` width/signedness semantics, so `repeat(-1)` is zero-trip while
`repeat(-32'hffff_ffff)` executes once. Wider values remain conservative.

Authorized non-static instance-constant assignments emit a
`%prop/const/init` VVP guard before the store. The guard test-and-sets state on
the receiving object. A second executed write terminates with a source-located
runtime diagnostic. Stack underflow, a non-object receiver, a non-const/static
property, and an out-of-range 64-bit property ID fail cleanly.

Out-of-block function and task methods resolve the class specialization through
their method scope and implicit `this`, preserving the same authorization and
runtime behavior as in-class bodies.

## Permanent evidence

The paired `-g2017`/`-g2023` sources cover:

- direct, `this.`-qualified, inherited, external, aggregate, and independent
  per-object initialization;
- conditional, repeat, procedural `for`, early-return, and detached-fork
  paths;
- header initialization outside a loop region, body/step sharing, literal
  true/false conditions, `continue` into the step, and `break` bypassing it;
- runtime duplicate writes from dynamic loops and distinct header/step sites;
- static-const for-header rejection, repeat-count imports/locals/formals,
  unary-negative and wide counts, and one unresolved-count diagnostic;
- definite initialization before an embedded-covergroup constructor plus the
  same-loop and `fork...join_none` structural prohibitions; and
- malformed `%prop/const/init` metadata.

A comparison compiler built from the same clean base accepts
`sv_class_static_const_for_init_fail` with exit 0 in both editions. The feature
compiler rejects it with the ordinary const-property diagnostic and exit 2.
Compiler fingerprints and commands are retained under
`evidence/opentitan-instance-const-after247-arm64-20260830/focused/`.

## Validation

| Gate | Result |
|---|---:|
| focused legacy | 44/44 |
| focused JSON/VVP | 44/44 |
| full SystemVerilog | 2,212/2,212 |
| full JSON/VVP | 1,290 entries, 0 failed |
| negative diagnostics | 149/149 |
| VPI | 103/103 |
| malformed VVP | 1/1 |
| real-DPI UVM | 354/354, 0 failed, 0 skipped |
| synthesis fast-path positives | 9/9 |
| synthesis negative sentinel | 1/1 |

`parse.y` was not changed, so the Bison grammar conflict surface is outside
this increment.

## Unmodified OpenTitan checkpoint and toolchain gotchas

OpenTitan was clean at `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`.
The focused `lowrisc:dv:rv_timer_sim:0.1` UVM compile used native ARM64 Python
3.13.15, FuseSoC 2.4.5, Edalize 0.6.3, HJSON 3.1.0, and the worktree-local
compiler. Setup and compile returned 0; the matrix reports **DEBT**, 0 hard
errors, and 17 unrelated semantic-debt diagnostics. The four former range
drops for `step`, `prescale`, `mtime`, and `mtime_cmp` are absent. This is a
compile-frontier improvement, not a runtime or application pass.

Use the logical `opentitan-python313/bin/python` path. Resolving the venv
interpreter bypasses its environment, and ambient Python 3.14 is not the
recorded toolchain. FuseSoC must receive that same interpreter explicitly.
The register generator CLI is `util/regtool.py`; there is no `util/reggen.py`.
A guarded UART regeneration produced `uart_reg_pkg.sv` and `uart_reg_top.sv`
byte-for-byte identical to the clean OpenTitan sources.

## Boundary

Only omitted/direct defined-literal procedural-`for` conditions receive a
definite true/false proof. Other constant expressions remain conservative.
Exhaustive constructor control flow and complete clauses 8 and 19 remain open.
