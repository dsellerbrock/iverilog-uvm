# §32 SDF issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. On 2026-10-21, open and closed issues were searched with `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state` for `"sdf_annotate"`, `"SDF"`, `"IOPATH"`, `"PATHPULSE"`, `"pulse limit"`, and `"32."`.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"sdf_annotate"` | none | No existing issue. |
| `"SDF"` | none | No existing issue. |
| `"IOPATH"` | none | No existing issue. |
| `"PATHPULSE"` | none | No existing issue. |
| `"pulse limit"` | none | No existing issue. |
| `"32."` | OPEN: #797, #739, #730, #691, #785, #747, #750, #692, #799, #761, #788, #760, #807, #737, #808, #826, #663. CLOSED: #666, #661, #680, #503, #533, #539, #17, #16, #27. | Broad numbering or text matches for unrelated language clauses, Caliptra, UVM, SVA, and prior work. |

No existing issue covers SDF `IOPATH` annotation, §32.8 rise/fall mapping, or §32.7 `PATHPULSE` annotation. The §32.7 outcome rules come from §30.7. If a failure remains with these balanced inputs and no `SDF ERROR` output, rerun a focused dedupe for that behavior before asking the audit lead to file.

After this probe and dedupe, the audit lead filed [#880](https://github.com/dsellerbrock/iverilog-uvm/issues/880) for the §32.7 `PATHPULSE` gap and missing §32.3 warning.
