# [IEEE 1800] §10.6.2 — force/release of nested unpacked array elements is unsupported

**Status:** Draft for the supervisor to file. This agent has not opened an issue.

**Related:** M9 #769 / PR #1121. The #769 guard must classify unpacked indices separately from a final packed bit/part select; nested-container force lowering is a distinct limitation.

## Expected behavior

IEEE 1800-2023 §10.6.2 permits a force/release target that is a singular variable reference. `d2[0][0]` selects a whole element through two unpacked dimensions; it is not a packed bit-select. Force/release should work or fail with a direct unsupported-feature diagnostic, rather than mislabel the target as a bit-select.

## Reproduction

Environment: MacBook-Air.local; Icarus 13.0-devel from the #769 local install after the dimension-rank change. Commands were run through `~/codex-supervisor/localrun`; source and logs are in this evidence directory.

The attached `sv_force_dyn_nested_element_unsupported.v` declares `logic [3:0] d2[][], q2[$][$], e[][2]` and applies force/release to `d2[0][0]`, `q2[0][0]`, and `e[0][0]`.

Commands: `local-install/bin/iverilog -g2017 -s sv_force_dyn_nested_element_unsupported -o /tmp/nested-2017.vvp ivtest/ivltests/sv_force_dyn_nested_element_unsupported.v` and the same command with `-g2023`. Both return rc=6 with six copies of `sorry: assignment to a dynamic-array element bit-select requires a simple vector element.` No §10.6.2 error is emitted. The message describes the whole selected unpacked element as a bit-select.

Control: `logic [3:0] d2[][]; initial d2[0][0] = 4'h1;` compiles successfully with `-tnull` under both editions. The failure is specific to force/release lowering. Exact control source and outputs are attached as `plain.sv` and `probe.log`.

**Classification:** IEEE implementation gap in nested-container force/release lowering, with misleading diagnostic wording. The two edition golds and full local runner logs are attached.
