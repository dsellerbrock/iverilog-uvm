# Flash nested queue-content strict controls

Current branch image tests for the prerequisite to the Flash solve-before blocker. The tests are already registered in the JSON and legacy regression lists; this checkpoint adds the exact strict paired runtime logs and image fingerprints. No OpenTitan source was changed.

## Result

All three existing fixtures pass under both strict language editions (**6/6 invocations**):

- `sv_constraint_fixed_queue_content`: nonempty `rand entry_t q[2][2][$]`, size constraints, nested `foreach`, packed struct fields, `dist`, and element checks.
- `sv_constraint_fixed_queue_content_boundaries`: confirms out-of-range queue element, unknown selected state, and contradiction controls fail without corrupting state; the fixture's expected diagnostics are in the stderr gold.
- `sv_constraint_class_state_fixed_2d`: Flash-shaped `rand bit mp_info_pages[2][2][$]` reads 2-D external state weights per queue leaf; invalid, X/Z, and null-path state-read controls fail closed. Its expected diagnostics are in the stderr gold.

For each edition, compile and runtime return zero, the fixture prints `PASSED`, and stdout/stderr match the registered gold channels. See [gold-channel-checks.txt](gold-channel-checks.txt), the paired compile/runtime logs, and the six VVP images. Strict flags are `-g2017` or `-g2023`, each with `-gno-icarus-misc -gno-xtypes`; no `-gcommercial-unsafe` is used for these language controls.

## Tool fingerprints

- `iverilog` SHA-256: `53969c0e4a140f0f2accec98b752c4d37529d912ddb255bec0ed5dc9d1a07bcc`
- `vvp` SHA-256: `215774b9c3f6f3affb0be206afe017554b64b51885516b55d51f9fd57e6cfca1`

## Boundary

This closes the nested queue-content prerequisite on the current dirty compiler image; it does not prove the OpenTitan Flash DV row. Census11 Flash still timed out after 3000 seconds, and its copied-source compile reports whole-array solve-before errors plus separate warnings. The next blocker is to qualify a standards-compliant, distribution-preserving ordering correction for the array variables before making a disposable-source patch. The pinned OpenTitan tree remains read-only; OpenTitan compile/runtime uses explicit `-gcommercial-unsafe` as required.
