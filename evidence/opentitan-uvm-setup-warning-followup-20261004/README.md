# OpenTitan UVM setup-warning follow-up

The 2026-10-04 census15 recorded 13 UVM compile rows as `DEBT` solely because
FuseSoC warned about staged C/C++ file types. The current runner rechecked all
13 against the generated Icarus source lists: **13/13 PASS**, with 89 raw
notices preserved as benign diagnostics and zero actionable setup warnings.

This classification is limited to the UVM compile lane. A warning is benign
only when its staged file is absent from the direct and nested Icarus `.scr`
lists. Runtime rows still require native DPI builds and checked runtime pass
markers; this compile result does not replace that evidence.

The copied OpenTitan source tree had no Git metadata, so its revision is
recorded as unknown. The [full JSON](result.json) and [row report](result.md)
contain the commands, diagnostics, source lists, and per-core results.
