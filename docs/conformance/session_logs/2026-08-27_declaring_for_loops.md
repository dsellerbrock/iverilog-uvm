# IEEE 1800 12.7.1 declaring for-loops (2026-08-27)

Merge base `ffa2b1f36a186a80076644ed8a5d312524529d7a` (origin/main after PR
240). Native Apple Silicon ARM64 throughout; Homebrew Bison 3.8.x; every
compiler and simulator process run through the shared resource runner with its
45-second CPU guard. A separate ARM64 worktree was built at the merge base and
used as the comparison compiler for every red/green claim below.

## What was wrong

IEEE 1800-2017/2023 Syntax 12-5 lets a `for_initialization` hold one or more
`for_variable_declaration`s, each with its own `data_type` and its own
comma-separated declarators. Only a single keyword-typed declaration parsed.
A typedef-led, package-qualified, or class-scoped list fell into the
`K_for '(' error ...` recovery rule, which emitted a warning and dropped the
loop — a silent-success path, since the loop simply did not run.

## Root causes found

### 1. The early-scope carrier was shadowed by the error rules

`for_loop_prefix` opens the implicit block right after `for (`, which is
required because an inline anonymous enum registers its literals at parse
time. But four `loop_statement` error alternatives still spelled
`K_for '('` literally, so the state after `for (` held both the carrier's
reduction and those alternatives, and Bison preferred the shift. Every
declaration-led header (TYPE_IDENTIFIER, PACKAGE_IDENTIFIER, ...) was diverted
into an lpvalue that only the error rules could complete.

`%precedence IDENTIFIER` (parse.y:2334) is declared after `%nonassoc '('`
(parse.y:2310), so IDENTIFIER out-ranks the carrier's rule precedence and the
ordinary `for (i = 0; ...)` header was diverted the same way. A
precedence-resolved decision is **not counted as a conflict and not bracketed
in the report**, so the conflict totals understated the breakage by exactly
the token that broke ordinary loops. Routing the four alternatives through the
carrier leaves that state with one item and a `$default` reduction.

The acceptance criterion used was therefore the item set of the state after
`for (`, not the conflict total.

### 2. Declarators were installed after the condition was lexed

Installation happened at the closing `)`. The condition and step are lexed
before that, so a declarator whose name shadows a visible typedef came back as
TYPE_IDENTIFIER and the condition bound to the type. `for (int shadow = 0;
shadow < 3; shadow++)` incremented `shadow` but never terminated — a silent
wrong answer with no diagnostic. Splitting the header at the first `;` fixes
it with no change to the conflict signature.

### 3. Three latent defects the feature made reachable

All three reproduce on the merge-base compiler and are fixed in a separate
commit with their own reducers.

`NetForLoop::index_` is null when a loop declares more than one control
variable. `synth_async` already rejected that with a `sorry`, but
`check_synth` dereferenced it through `print_for_idx_warning`, and
`nex_input` dereferenced `index_->pin_count()` while `always_comb` built its
implicit sensitivity list. Both segfaulted. On the merge base this is reached
by `for (int i = 0, byte j = 1; ...)` inside `always_comb`; the feature made
it reachable from ordinary single-variable RTL as well, which is how it was
found.

`NetEvent::find_similar_event` merged events across an automatic call-frame
boundary. The guard tested only whether the event being placed was itself in
an automatic scope, missing the reverse direction. A static-scope event merged
into an automatic-scope candidate, the survivor became context-local, and the
static-scope waiter aborted in `vthread_add_event_wait` on a null wait-list
head. The test is now symmetric and uses a new `NetScope::owns_call_frame()`
mirroring tgt-vvp's `scope_needs_call_frame()`, because a static named block
holding automatic declarations also owns a frame — which is the case reached
here.

## Conflict state

| Grammar | shift/reduce | reduce/reduce |
|---|---:|---:|
| Merge base | 535 | 1115 |
| This branch | 535 | 1119 |

The four added reduce/reduce are the packed-dimension-versus-index decision in
the class-scoped initializer states, where `C::nibble_t [1:0] v = ...` and
`C#()::values[0] = ...` spell the same symbols. Both are parsed through one
shared `dimensions` carrier and separated on the following token. No other
conflict state changed its item signature; the comparison was made by
canonicalizing every conflicting state's item core with midrule numbering
normalized, not by comparing totals.

## Validation

All against this worktree's `local-install`.

| Suite | Result |
|---|---|
| ivtest legacy `regress-sv.list` | 1952/1953; the one failure is `sv_package_lazy_subroutine_scope`, which also fails at the merge base. Zero failure-set delta. |
| ivtest JSON/VVP `regress-vvp.list` | 1031 ran, 0 failed |
| `tests/negative/run_negative.sh` | 136 passed, 0 failed |
| ivtest `vpi_reg.pl` | 103/103 |
| `.github/uvm_test.sh` (real DPI) | 354 passed, 0 failed, 0 skipped |

Three `decl_before_use` gold files gained the new "declared here" note. Their
error counts and exit statuses are unchanged; the diff is one added line each.

### Red against the merge base, green here

| Reducer | Merge base | This branch |
|---|---|---|
| `for (E e = e.first(), int i = 0; ...)` | syntax error + dropped loop | compiles and runs |
| `for (int shadow = 0; shadow < 3; shadow++)` with `typedef int shadow` | never terminates (CPU guard, exit 152) | 3 iterations |
| `loop2: for (int i = 0; ...)` | syntax error | `%m` reports `t.loop2` |
| `sv_always_comb_for_null_index` | segfault (139) | diagnosed, exit 2 |
| `sv_auto_block_shared_wait_event` | abort (134) | PASSED |

## Known limitations

A loop variable that has left scope is still only a compile-progress warning
with a zero exit. That is general to this compiler's block scopes — a plain
named block and the merge-base compiler behave identically — so it was not
changed here. Non-escape is asserted semantically instead, and the boundary is
recorded in the clause matrix.

`%m` reports no named block from inside a subroutine, including a plain
`begin : name`. The labeled-implicit-block assertion is therefore made at
module level. This is a pre-existing limitation unrelated to 12.7.1.

Bare `type(expr)` is rejected through generic error recovery and emits a
cascade of five diagnostics. The cascade is byte-identical at the merge base;
the gold file pins it exactly rather than claiming a focused single error.

## Not covered by this change

No OpenTitan or Caliptra matrix was replayed for this section. This closes one
clause cluster; it is not evidence about the UVM compile or runtime lanes,
which stood at 0/61 and 0/77 in the 2026-08-26 baseline.
