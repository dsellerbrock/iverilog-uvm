# Open and closed issue dedupe — §23.8 explicit `$unit` forward reference

Fresh GitHub snapshot queried after the paired probe: 436 issues total (309 open, 127 closed). Raw results are in `open-issues-live.json`, `closed-issues-live.json`, and combined `dedupe-all-issues.json`; titles and bodies were searched.

## Exact searches

| Search term | Hits |
| --- | ---: |
| `$unit::b` | 0 |
| `$unit forward variable` | 0 |
| `compilation unit forward variable` | 0 |
| `later compilation-unit item` | 0 |
| `unit scope forward reference` | 0 |
| `name resolution` | 0 |

## Expanded searches and neighbors

- `$unit`: 2 — open #926 is `$printtimescale($root/$unit)` in §20.4.2; closed #19 is a broad language-edge tracker that mentions `$unit::name` visibility but has no §23.8 before-declaration behavior or reproducer.
- `compilation unit`: 4 — #926, #876 (anonymous program in package), #817 (§26.2 package item referring to a compilation-unit item), and #19. These test different requirements.
- `compilation-unit`: 7 — the above plus #842/#841 (class constraint declarations), #818 (unpacked struct ports), and #773 (let declarations). All are distinct.
- `forward`: 9 — #762/#760/#751 concern type/class forward declarations; closed #500 is unresolved hierarchical task calls; #483/#477 are `ref` forwarding; #100/#30 are unrelated; closed #19 is the broad tracker. No issue tests a `$unit::` reference to a later variable declaration.
- `before use`, `after use`: 0; `declaration order`: only open #727, a distinct assertion `disable iff` rule.

Potential umbrella overlap for the audit lead to resolve: closed #19 broadly lists file-scope declarations visible via `$unit::name`, but its scope does not specifically list or reproduce a forward reference to a later compilation-unit declaration. No direct open or closed duplicate was found.
