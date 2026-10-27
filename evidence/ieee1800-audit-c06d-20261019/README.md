# IEEE 1800 clause 6.20 probes

Run on 2026-10-19 under `~/codex-supervisor/localrun 300` with
`run-p06-20.sh`. Host: Darwin ARM64. Audit checkout HEAD:
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`. Compiler source:
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
The serial run took 3.81 s and peaked at 17,006,592 bytes RSS. Per-test
compile and run logs are saved in `attempt-01/`.

## Results

- `p06_20a_values.sv`: both `-g2017` and `-g2023` compile and run with
  `RESULT pass=12 fail=0`; outputs include both parameter override widths,
  the real override `2.500000`, and the expected values.
- `p06_20b_type_local_const.sv`: both editions compile and run with
  `RESULT pass=5 fail=0`; type parameter, localparam, specparam, const
  variable, mutable class member through a const handle, and automatic
  task-local const outputs match the expected values.
- The eight baseline negatives (const assignment, type `defparam`,
  hierarchical parameter reference, missing localparam default, localparam
  override, missing required parameter, specparam in a general constant
  expression, and non-type value for a type parameter) reject in both
  editions. The specparam case reports the §6.20.5 diagnostic.
- `p06_20c_fwd_type_2023.sv`: 2017 rejects the 2023-only syntax as expected;
  2023 also rejects at line 1 with `syntax error`. The 2023 result is a
  conformance gap candidate for module parameter-port forward-type syntax.
- `n06_20_fwd_nonconforming.sv` rejects in both editions. In 2023 it is
  rejected by the same syntax failure, so this does not qualify semantic
  category checking for a parsed forward type.

## Issue dedupe

On 2026-10-19, searched all states (`gh issue list --state all --limit 100`)
for: `parameter`, `localparam`, `specparam`, `defparam`, `type parameter`,
`parameter override`, `implied range`, `$isunbounded`, `const`, `const handle`,
`forward type`, `type enum`, and `incomplete class`. Sorted unique hits:

| Issue | State | Title |
|---:|---|---|
| #19 | CLOSED | Phase 15: Language edge cases — $unit, type params, interfaces, structs, bind, patterns |
| #27 | CLOSED | OpenTitan UART DV: VVP generates (0 errors), runtime stubs needed |
| #29 | CLOSED | Phase 58: wait()-loop sensitivity through virtual-interface signal chain |
| #30 | CLOSED | Phase 59: UVM port-imp virtual dispatch (seq_item_port.try_next_item) |
| #47 | CLOSED | Phase 75: Fallback hardening — eliminate remaining warning noise |
| #99 | CLOSED | Unpacked-array typedef as a function return type loses its element type |
| #100 | CLOSED | Class-property unpacked array of real/string stores every element to the same slot |
| #436 | CLOSED | [IEEE 1800] §6 — Resolve selected and generic operands in interconnect concatenations |
| #450 | CLOSED | [IEEE 1800] §8 — Support associative-array-typed parameters |
| #451 | CLOSED | [IEEE 1800] §8 — Support restricted class type parameters |
| #474 | CLOSED | [IEEE 1800] §§10.9/6.22 — Elaborate fixed-array parameter assignment patterns and element reads |
| #477 | CLOSED | [IEEE 1800] §§13.5.2/6.22.2 — Reject non-equivalent ref actual types |
| #483 | CLOSED | [IEEE 1800] §13.5.2 — Allow const-ref forwarding to const-ref formals |
| #502 | CLOSED | [IEEE 1800] §§7.4.6/11.4.2 — Update fixed-array elements for increment expressions |
| #533 | CLOSED | [SystemVerilog] Parse package-qualified parameterized class handles in interfaces |
| #539 | CLOSED | Packed struct assignment pattern member loses enum value with wider sibling expression |
| #611 | OPEN | [IEEE 1800] §8.5 — Accept class-scoped type parameter as cast type (C#(3)::T'(x)) |
| #635 | OPEN | [IEEE 1800] §13.4 — Reject output/inout/ref function calls outside procedural statements |
| #638 | OPEN | [IEEE 1800] §13.4.3 — Reject fork constructs in constant functions |
| #659 | OPEN | [IEEE 1800] §19.4 — Embedded covergroup in a parameterized class: malformed runtime metadata and coverage 0.0 |
| #663 | OPEN | from-caliptra-dv: inherited type parameters lose transfer members |
| #666 | CLOSED | from-caliptra-dv: parameterized UVM transfer $cast fails with class localparam |
| #670 | OPEN | from-caliptra-dv: classify trailing empty $psprintf argument |
| #671 | OPEN | from-caliptra-dv: dynamic-array slice assignments in class properties |
| #698 | OPEN | [IEEE 1800] §13.4.3 — Reject void function invocations inside constant functions |
| #712 | OPEN | [IEEE 1800] §16.9.4 — Support global clocking past and future sampled value functions |
| #737 | OPEN | [IEEE 1800] §6.19 — enum constant value 'x does not expand to all base-type bits |
| #743 | OPEN | [IEEE 1800] §6.24.2 — $cast with a non-singular (unpacked array) destination returns 1 without assigning |
| #745 | CLOSED | [IEEE 1800] §6.24.2 — $cast with a non-singular (unpacked array) destination returns 1 without assigning |

Bodies reviewed for #19, #100, #436, #450, #451, #474, #533, #611, #663,
and #666. #19 is a broad closed tracker. #451 was closed by PR #579; its
restricted enum/struct/union/class tests cover class parameter forms, not the
module parameter-port reproducer here. #450 is associative-array value
parameters; #611 is a class-scoped cast; #474 is keyed array assignment
patterns; #663 is inherited class-member lookup. The other matches are outside
this syntax/behavior. Previously identified exclusions #435, #97, and #728
remain outside scope; #474 is already closed.

## Existing records

The current `ieee1800_status.md` had no §6.20 rows before this probe. The legacy
clause matrix's aggregate §6 row records only selected parameter cases:
`$`/`$isunbounded` under §6.20.2.1, specparam exclusion from general constant
expressions under §6.20.5, and other tested subsets. `BLOCKERS.md` records S06
named parameter/localparam SVA delay behavior, L08 class-scoped type actuals
(§6.20.3/8.23), L16 direct const-handle member writes (§6.20.6), and L26 class
parameter defaults. `DISCOVERED_DEBT.md` DD-008 cites §6.20.2 but its named
delay scope is resolved in S06; DD-033 cites #474 (the issue is now closed);
DD-041's outer-parameter class-method localparam crash is fixed. None of these
records covers module forward-type syntax.

## Forward-type reduction

The first lead-provided reduction script had a helper-call typo (`r1_enum`
instead of `r r1_enum`), so attempt 01 created no forward-type sources. Only
the const-handle reassignment control ran and rejected as expected; this is
not probe evidence. The corrected serial run is `run-p06-20-reduction.sh`,
attempt 02, under `~/codex-supervisor/localrun 300`; transcript:
`reduction-attempt-02-localrun.log`. It took 2.30 s and peaked at 16,924,672
bytes RSS.

- In `-g2023`, all four module forms (`type enum E`, `parameter type enum E`,
  `type struct S`, `type class C`) reject at line 2 with a syntax error.
  The plain module `type E` control compiles.
- In `-g2023`, the class restricted-type positive compiles and the class
  `type enum` with an `int` actual rejects with the correct restriction error.
- In `-g2017`, the four module restricted forms and the class restricted
  forms reject; the plain type parameter control compiles.
- Const-handle reassignment rejects in both editions.

This isolates the 2023 syntax gap to `forward_type` on module parameter ports,
independent of the anonymous enum/packed-struct defaults in the original
positive. #451/#579 covers class parameters only. A module semantic-negative
cannot reach the conformance check before the grammar parses; the class
negative already confirms the category-check path.

The reduced reproducer was filed as [#751](https://github.com/dsellerbrock/iverilog-uvm/issues/751)
with label `1800-audit`, following the tech lead's approved filing text.
