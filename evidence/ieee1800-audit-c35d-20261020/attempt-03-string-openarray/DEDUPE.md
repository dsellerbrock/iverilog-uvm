# Open and closed issue search

GitHub searches in `dsellerbrock/iverilog-uvm` used `--state all`:

| Search | Results and assessment |
| --- | --- |
| `svOpenArrayHandle string` | No matches. |
| `DPI import string open array` | Closed #13 is the broad DPI-completeness phase; it does not identify `string[]` open-array formals. No open match. |
| `DPI string array` | Closed #13 is broad DPI history; closed #27 is an unrelated OpenTitan runtime-stub report. No open match. |
| `string open array` | Open #734–#736 and #731–#733 concern string operations; #850, #856, #858 and #859 are unrelated queue/query/concatenation issues. Closed #44/#47 are generic parser cleanup. None covers DPI `string[]` open-array formals. |
| `open array non-atom` | No matches. |

No direct open or closed issue for the probed `string[]` DPI open-array
formal was found. Closed #13 is broader prior work, not a duplicate report of
this specific unsupported element type.
