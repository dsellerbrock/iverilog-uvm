# Open and closed issue search

GitHub searches in `dsellerbrock/iverilog-uvm` used `--state all`:

| Search | Results and assessment |
| --- | --- |
| `DPI unpacked struct open array` | Closed #544 is an ordinary SystemVerilog open-array actual compatibility issue, not a DPI issue. No direct match. |
| `svOpenArrayHandle struct` | No matches. |
| `DPI open array struct` | Closed #544 is the same unrelated ordinary SystemVerilog issue; closed #13 is broad DPI phase history, not a specific structure-element gap. No direct open match. |

No direct open or closed issue for an unpacked-structure element in a DPI
open-array formal was found. The result matches the same unsupported
non-scalar-element diagnostic as the independently probed `string[]` case;
these are submitted to the lead as one possible shared limitation.
