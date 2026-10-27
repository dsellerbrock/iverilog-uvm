# Open and closed issue search — chandle DPI ABI

GitHub searches used `--state all`:

| Search | Matches | Review |
|---|---|---|
| `chandle DPI` | #764, #763, #759 (open); #13 (closed) | The open issues cover forbidden port/packed/member uses and assignment to `int`, not a legal DPI return/input ABI. Closed #13 is a broad DPI phase, not a report of an ABI gap. |
| `"chandle ABI"` | none | No direct match |
| `"35.5.6" chandle` | none | No direct match |
| `chandle void pointer` | #13 (closed) | Broad DPI-completeness issue only |

The probe reuses an existing regression and does not indicate a new gap; no
issue is proposed.
