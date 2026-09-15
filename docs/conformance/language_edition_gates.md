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

## Implemented feature gates

[`sv_edition.h`](../../sv_edition.h) is the source of truth for the feature
table. It currently includes the 2023 `$stacktrace` task and the constant
`option.cross_retain_auto_bins` subset. Iterator `index()` is metadata for
SystemVerilog 2005, not a 2023-only feature. The
[2023 survey](ieee1800_2023_delta.md) owns the detailed edition dispositions.

## Edition boundaries

The selector chooses language rules; it does not certify implementation.
A keyword disabled in an earlier edition becomes an ordinary identifier.
Feature checks therefore also belong in parsing/elaboration. Shared rules
need paired tests, and edition-specific constructs need earlier-edition
rejection tests. Do not infer identical semantics merely from shared syntax.

## What this does not claim

Selecting `-g2023` does not mean IEEE 1800-2023 is implemented. Consult the
survey for tested subsets and gaps. Edition gates enforce the recorded
feature boundaries; they do not establish exhaustive edition qualification.

Per the campaign directive: do not claim edition conformance merely
because the command-line switch exists.

## Test matrix

The `$stacktrace` gate carries four core arms, registered in
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

Iterator index querying has a separate boundary matrix matching its
actual history:

| arm | registration | asserts |
|---|---|---|
| pre-SystemVerilog mode | `CE,-g2005` + `gold=` | the array-method expression is rejected by the IEEE 1364-2005 grammar |
| defining edition | `normal,-g2005-sv` | `item.index` works and computes the right value in IEEE 1800-2005 mode |
| next edition | `normal,-g2009` | the feature remains available in the immediately following SV edition |
| latest edition | `normal,-glatest` | the feature remains available in the newest selectable edition |

## Related defect fixed alongside

`draw_sfunc_string` (`tgt-vvp/eval_string.c`) asserted that a system
function used in a string context returns a string. It did not — `string
s; s = $time();`, or any typo'd `$bogus()`, aborted the compiler with a
raw assertion and exit 134. It now emits a located diagnostic naming the
function. This was found while probing `$stacktrace()`'s function form,
which is one such case.
