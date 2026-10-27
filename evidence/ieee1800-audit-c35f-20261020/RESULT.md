# IEEE 1800 §§35.1–35.3 coverage mapping

## Standard basis

IEEE 1800-2017 and 1800-2023 §§35.1–35.3 introduce DPI tasks/functions, the
SystemVerilog and foreign-language layers, and the interface between them.
The text says the SystemVerilog layer is independent of the foreign language;
the standard defines the foreign-language layer for C. These overview sections
do not add a separate call syntax beyond the imports, exports, and protocols
probed in §§35.4–35.9.

## Passing probes reused for the listed subsets

- [Basic import/export probe](../ieee1800-audit-c35a-20261020/attempt-01-basic/RESULT.md), Slurm job 3557: `p35_basic.sv` and `dpi_basic.c` are compiled separately, then linked through generated DPI glue. In both `-g2017` and `-g2023`, C imports and the C-to-SV exported function callback pass with output `D1 5`, `D2 3.0`, `D3 hi bob`, `D4 7`, `D5 50`.
- [Task/disable probe](../ieee1800-audit-c35b-20261020/attempt-02-active-dup/RESULT.md), Slurm job 3559: import/export task and function-disable paths pass in both editions. The exact successful output and raw toolchain evidence are in that result directory.
- These results support only the tested C DPI paths. They do not claim support for unspecified foreign languages or every behavior listed in Clause 35.
- The paired probes used source commit `cc25756d1`; current `origin/main` is `fb584a251`. A diff audit found no changes to `parse.y`, compiler elaboration, `tgt-vvp`, `vvp_dpi.cc`, or `vthread.cc` between those commits. Changes in `vvp` were limited to class-object, performance-statistics, and Z3 files, so the existing DPI probes remain direct evidence for these subsets; they were not rerun.

## Matrix treatment

Rows for §§35, 35.1, 35.2, and 35.3 now point to these tested subsets and remain
`PROBED — LEAD PENDING`; the lead must decide their final classification. No
new gap candidate or issue was identified by this scope mapping.
