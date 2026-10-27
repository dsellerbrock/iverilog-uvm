# Open and closed issue dedupe — §§23.8, 23.8.1, 23.9

Fresh GitHub snapshot: 436 total issues (309 open, 127 closed), stored in `dedupe-all-issues.json`. Search covers titles and bodies, open and closed.

## `upward reference` — 0 hit(s)
- No hits.

## `upwards name` — 0 hit(s)
- No hits.

## `hierarchical upward` — 0 hit(s)
- No hits.

## `$unit function` — 0 hit(s)
- No hits.

## `compilation unit function forward` — 0 hit(s)
- No hits.

## `name resolution generate` — 0 hit(s)
- No hits.

## `wildcard import hidden` — 0 hit(s)
- No hits.

## `duplicate name generate` — 0 hit(s)
- No hits.

## `23.8` — 0 hit(s)
- No hits.

## `23.9` — 0 hit(s)
- No hits.

Expanded term checks on the same snapshot: `upward` (no hits), `hierarchical reference` (#921, #906, #812, #761, #758, #611; unrelated to §23.8 resolution), `name resolution` (no hits), `scope name` (#791 `$typename`, unrelated), `duplicate declaration` / `duplicate identifier` (no hits), `generate block` (#930/#928 defparam, #822/#821/#774/#773/#767; separate rules), `compilation unit` (#926 `$printtimescale`, #876 program in package, #817 package reference, closed #19 broad Phase 15 tracker), `$unit` (#926 and #19), `wildcard import` (no exact hits), and `forward function` (no hits).

Nearby closed #19 is a broad language-edge implementation plan that mentions `$unit` and module-level interface connections, but contains no §23.8.1 forward subroutine-resolution requirement or reproducer. Open #817 tests the separate §26.2 prohibition on a package item referring to a compilation-unit variable; #930/#928 are separate §23.10 `defparam` rules. No direct duplicate found for the assigned cases.
