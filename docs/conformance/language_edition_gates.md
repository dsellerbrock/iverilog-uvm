# Language-edition feature gates

How `-g<edition>` is selected, what it actually enforces, and — just as
important — what it does not.

## The selector

`sv_edition.h` holds `SV_EDITION_TABLE`, one row per selectable edition.
Both programs expand it:

| consumer | file | what it takes from the table |
|---|---|---|
| driver `-g` parser | `driver/main.c` | accepted spellings |
| driver "is this SystemVerilog?" | `driver/main.c` | the `SV` column |
| compiler token → `generation_t` | `main.cc` | `TOKEN` → `GEN` |
| lexer keyword-mask cascade | `main.cc` | `GEN` ordering |
| verbose banner | `main.cc` | `IEEE` display name |

The driver and the compiler are separate programs communicating only
through the `generation:<token>` line of the iconfig file, so before this
table the list was hand-written on both sides and in five further places.
It had already drifted: `command_line_flags.rst` omitted `2005-sv`, and
the driver's `v2005_math.vpi` test omitted it while its own comment
claimed the whole 2005 family.

Adding an edition = adding one row, plus one `case` in the keyword
cascade. The cascade now has a `default` that fails loudly; without it a
`generation_t` with no case left `lexor_keyword_mask` at 0, which lexes
**every keyword as an identifier** — a whole-source misparse with no
diagnostic.

## The capability layer

`SV_FEATURE_TABLE` maps a feature to the edition that *introduces* it.
Call sites ask `sv_require_feature(loc, SVF_x)` rather than comparing
version numbers, which is what makes the diagnostic possible: a raw
comparison knows only that a test failed, while a table row knows the
construct's name and its edition, so the message can name the construct,
the edition, and the flag without the call site spelling any of them out.

```
error: the $stacktrace system task requires IEEE1800-2023;
       compile with -g2023 (or -glatest).
```

Reports are deduplicated per (location, feature): elaboration visits an
expression more than once, and the message otherwise printed two or three
times for one line.

## What is gated today

| feature | edition | gated at | earliest layer? |
|---|---|---|---|
| `$stacktrace` task | 1800-2023 | `PCallTask::elaborate` | yes — the compiler has no system-task name table before elaboration; names are otherwise resolved at VPI link time |
| `index` iterator property | 1800-2023 | `elab_expr.cc` member resolution | yes — `.index` is an ordinary member path until the receiver's type is known |

Both were previously accepted under `-g2012` and *executed with correct
2023 semantics*, so a user asking for 1800-2012 silently got 1800-2023.

## Scope findings that shaped this work

**IEEE 1800-2017 introduces no new syntax.** It is a maintenance/errata
revision of 1800-2012. The set of "2017-only additions used by this fork"
is therefore **empty**, and no `SV_FEATURE_TABLE` row names `GN_VER2017`.
`-g2017` exists so a design can state the edition it targets — this fork
documents itself against 1800-2017 — not because it gates anything.
`-g2012` and `-g2017` accept the same language by construction, and a
test pins that a 2023 feature is refused under `-g2017` exactly as under
`-g2012`.

**The 1800-2023 leak surface was two constructs, not many.** Every other
item in `ieee1800_2023_delta.md` and in the campaign's gate list
(triple-quoted strings, `ref static`, `type(this)`, restricted type
parameters, `dist default :/`, class/method specifiers, soft unions,
`map()`, covergroup `extends`, `weak_reference`, `rand real`, tolerance
ranges, preprocessor booleans) is *unimplemented* and already rejected in
every mode. Checker constructs are 1800-2012 clause 17, so accepting them
is correct, not a leak.

**The keyword table was already correctly tiered.** Every keyword's mask
bit matches the edition that introduced it, and this fork never modified
`lexor_keyword.gperf`. The gap was that no tier existed above 2012 and
that the fork's own constructs key off `gn_system_verilog()` — true for
anything ≥ 1800-2005 — rather than a tier.

A keyword whose bit is off becomes an ordinary `IDENTIFIER` with no
diagnostic. That is **correct**: if `unique0` is not reserved in 2005,
using it as a variable name must be legal. Edition gating for constructs
therefore belongs at the grammar/elaboration layer, not in the lexer.

## What this does not claim

Selecting `-g2023` does not mean IEEE 1800-2023 is implemented. Most of
that edition is unimplemented and rejected in every mode. The flag
guarantees the converse only: constructs this compiler *has* implemented
from an edition are available only when that edition is requested.

Per the campaign directive: do not claim edition conformance merely
because the command-line switch exists.

## Test matrix

Each gated feature carries four arms, registered in
`ivtest/regress-sv.list`:

| arm | registration | asserts |
|---|---|---|
| older mode | `CE,-g2012` + `gold=` | fails, and the diagnostic names construct + edition + flag |
| defining edition | `normal,-g2023` | works, and computes the right value |
| later edition | `normal,-glatest` | still works |
| neighbour syntax | `normal,-g2012` | closely-related older syntax is undisturbed |

`$stacktrace` carries a fifth arm, `CE,-g2017`, pinning that a 2023
feature is refused under 2017 — the concrete check that 2017 is not
silently treated as "newest".

## Related defect fixed alongside

`draw_sfunc_string` (`tgt-vvp/eval_string.c`) asserted that a system
function used in a string context returns a string. It did not — `string
s; s = $time();`, or any typo'd `$bogus()`, aborted the compiler with a
raw assertion and exit 134. It now emits a located diagnostic naming the
function. This was found while probing `$stacktrace()`'s function form,
which is one such case.
