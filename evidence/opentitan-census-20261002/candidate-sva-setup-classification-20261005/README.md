# SVA setup-warning classification

Four SVA compile rows that were marked `DEBT` in the frozen 309-row snapshot
pass on clean OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`
with candidate engine `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`:

| Core | Result | Setup warnings classified benign |
| --- | --- | ---: |
| `lowrisc:dv:otbn_sva:0.1` | PASS | 7 |
| `lowrisc:dv:rv_core_ibex_sva:0.1` | PASS | 9 |
| `lowrisc:dv:sram_ctrl_sva:0.1` | PASS | 7 |
| `lowrisc:dv:top_earlgrey_sva:0.1` | PASS | 9 |

The existing classifier now applies to SVA as well as RTL/UVM. A C, C++, or
Python setup warning is benign only when the staged file exists and is absent
from the recursively read Icarus source lists. Warnings for files Icarus is
actually asked to compile remain actionable. No source or compiler behavior
was changed by this classification.

The [machine result](result.json), [matrix report](result.md), and per-row
setup/compile logs record the evidence. This focused follow-up does not update
the frozen 309-row totals or the 49-target runtime result.
