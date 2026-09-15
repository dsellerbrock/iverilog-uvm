# L43 — Procedural package imports

Legal imports after local declarations now resolve types and values without
creating an unelaboratable PNoop. The parser routes these declarations through
sequential block/routine lists, rejects them after executable or explicit null
statements, and excludes direct conditional/loop bodies. Attributed imports
avoid the null-statement attribute dereference. Explicit null statements retain
an empty PBlock, the existing no-op representation, for placement checking.

Normative basis checked separately in local IEEE 1800-2017 and 1800-2023:
A.2.1.3, A.2.6-A.2.8 and 26.3. No edition-specific change is claimed.

The original DD-018 reducer was invalid before the import: it used a function
return type only imported later inside the body. Correcting that type showed
leading imports already worked. Imports following a local int declaration
exposed the actual PNoop error. Both editions produced six internal elaboration
errors on the permanent positive source before the fix. A scratch duplicate of
an existing block_item_decl rule reproduces the prior +222 reduce/reduce jump;
state 1230 shows the two identical reductions, not a DPI ambiguity.

A first one-line candidate passed the initial positive checks but failed review:
it accepted illegal import placements and crashed with attributes. The final
list-based implementation addresses those failures. Bison reports 562
shift/reduce and 1122 reduce/reduce conflicts, versus 563/1122 at baseline; the
removed conflict corresponds to the former import-as-statement alternative.

Fresh final validation (local-install in the campaign worktree):

- `perl vvp_reg.pl regress-procedural-import-legacy.list`: 3/3, exit 0.
- `python3 vvp_reg.py regress-procedural-import-vvp.list`: 6/6, exit 0.
- Positive/late/control-body tests run independently in 2017 and 2023 modes;
  negative diagnostic text is pinned by legacy and split-stream gold files.
- Direct null-statement checks (if/else, delay, event, immediate assertion)
  pass in both editions; concurrent_explicit_null compiles with the null target.
- `git diff --check`: clean.

Durable local logs: `evidence/dd018-assessment/final-focus-legacy.log` and
`final-focus-json.log`. Original failures: `red-2017.log` and `red-2023.log`.
The make-check run belongs to the initial one-line candidate and is not counted
as final-patch regression evidence. Full suites are explicitly deferred to the
user-directed approximately ten-feature batch boundary. This is the first
focused-validated feature in that batch, not full package qualification.

Parallel assessment reduced the unmodified OpenTitan PRINCE abort to packed
mixed-driver compound assignment (DD-019). It is the next candidate, not part
of this implementation. No OpenTitan/Caliptra source was modified.
