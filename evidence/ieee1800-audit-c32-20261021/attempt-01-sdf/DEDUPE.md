# §32 SDF issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. On 2026-10-21, open and closed issues were searched with `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state` for `"sdf_annotate"`, `"SDF"`, `"IOPATH"`, and `"32."`.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"sdf_annotate"` | none | No existing issue. |
| `"SDF"` | none | No existing issue. |
| `"IOPATH"` | none | No existing issue. |
| `"32."` | OPEN: #797, #739, #730, #691, #785, #747, #750, #692, #799, #761, #788, #760, #807, #737, #808, #826, #663. CLOSED: #666, #661, #680, #503, #533, #539, #17, #16, #27. | Broad numbering or text matches for unrelated language clauses, Caliptra, UVM, SVA, and prior work. |

No existing issue covers SDF `IOPATH` annotation or §32.8 rise/fall mapping. Before filing any issue, rerun a focused open+closed dedupe for its observed failure mode.
