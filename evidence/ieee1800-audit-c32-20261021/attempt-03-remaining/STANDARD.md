# IEEE 1800 Clause 32 basis

Checked against both local edition PDFs. The task assignment's interconnect and default-value labels needed correction; citations below follow the standards text.

## §32.4.2 timing-check mapping

Table 32-2 maps SDF timing-check constructs to SystemVerilog checks (2017 p. 894; 2023 p. 926). Relevant and neighboring entries are:

| SDF timing check | Annotated SystemVerilog check |
| --- | --- |
| `SETUP v1` | “`$setup(v1), $setuphold(v1,x)`” |
| `HOLD v1` | `$hold(v1), $setuphold(x,v1)` |
| `SETUPHOLD v1 v2` | `$setup(v1), $hold(v2), $setuphold(v1,v2)` |
| `RECOVERY v1` | `$recovery(v1), $recrem(v1,x)` |
| `REMOVAL v1` | `$removal(v1), $recrem(x,v1)` |
| `RECREM v1 v2` | `$recovery(v1), $removal(v2), $recrem(v1,v2)` |
| `SKEW v1` | `$skew(v1), $timeskew(v1)` |
| `BIDIRECTSKEW v1 v2` | `$fullskew(v1,v2)` |
| `WIDTH v1` | `$width(v1,x)` |
| `PERIOD v1` | `$period(v1)` |
| `NOCHANGE v1 v2` | `$nochange(v1,v2)` |

The probe uses SDF `(SETUP d (posedge clk) (5))` against `$setup(d, posedge clk, 1, notifier)`. A data transition 3 ns before the clock must violate the annotated 5 ns limit; it must not violate the unannotated 1 ns control limit.

## Interconnect annotation

The applicable interconnect section is **§32.4.4** in both editions, not §32.5. Section §32.5 is “Multiple annotations”; §32.6 is “Multiple SDF files.” Table 32-3 maps SDF `INTERCONNECT` to an interconnect delay (2017 p. 896; 2023 p. 928). The standard describes interconnect delay as “the signal propagation delay from an output or inout module port to an input or inout module port.” The probe uses `u1.y` to `u2.a` and expects 3 ns.

## §32.9 `$sdf_annotate` options and defaults

Syntax 32-1 (2017 p. 900; 2023 p. 932) accepts optional `mtm_spec`, `scale_factors`, and `scale_type` strings after the file, instance, config file, and log file.

- Table 32-5 (`mtm_spec`, 2017 p. 900; 2023 p. 932) lists `MINIMUM`, `TYPICAL`, and `MAXIMUM`; **`TOOL_CONTROL` is the default**, not `TYPICAL`.
- The `scale_factors` default is `1.0:1.0:1.0` (2017 p. 900; 2023 p. 932).
- Table 32-6 (`scale_type`, 2017 p. 901; 2023 p. 933) lists `FROM_TYPICAL` as applying scale factors to the typical value; **`FROM_MTM` is the default**.

The lead's assignment called §32.5 the interconnect section and described TYPICAL as the `mtm_spec` default. Both PDFs instead place interconnect at §32.4.4 and make `TOOL_CONTROL` the `mtm_spec` default. This probe follows the standard's section numbers and explicitly selects `TYPICAL` for its typical-value run.
