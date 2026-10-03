# ADC current-image checkpoint — 2026-10-02

Source checkout: `b0bdbe63f` plus dirty worktree changes. Pinned OpenTitan source remained at `a78922f14a8cc20c7ee569f322a04626f2ac6127`.

## Closed ADC solver blockers

The paired `-g2017` / `-g2023` dynamic-array reducers pass, including ADC-shaped 66-bit packed structs, indexed nested-row sizes, dependent elements, package `const` defaults, preallocated-row retention, and contradiction rollback.

The paired projected-bit `dist` / `solve before` regression passes. The wide nested graph-variable path is covered by the paired nested-array reducer. These fixes move the selected ADC smoke past the former joint-distribution and 66-bit-variable failures.

## Selected ADC smoke

The prepared pinned `lowrisc:dv:adc_ctrl_sim:0.1` image has SHA-256 `cfe231bc55b403efb5df331ffae2ed697bb89cff3c0ae13b8dd5637f548b3b57`. Re-running it with the rebuilt root VVP completes with `TEST PASSED CHECKS`, `UVM_ERROR: 0`, `UVM_FATAL: 0`, and zero warnings. The run ends at 5,928,290,755 ps.

Current build hashes:

- `ivl`: `6a18cb3c8c4da86ad3e230935d8085635ea015e9fbf24eb4f6e07a8fd6ed384b`
- `vvp/vvp`: `345645bee4da62c3100d722d7839c05503d9ad1dd585fbd3a7c700950eeae975`

Runtime evidence: [ADC post-wide-joint log](adc-post-wide-joint-runtime.log). The original compile warnings about `rst_n` coercion and nonblocking assignments in `always_comb` are unchanged and are not ADC randomization failures.

## Census and gate context

The latest complete 49-core census is Claude Code's census6, generated at `2026-10-02T04:22:06Z`: **37 PASS, 7 DEBT, 2 FAIL, 3 RUNTIME_FAIL**. It used engine SHA-256 `3d5962e6667b119d15037caff296b221c575c4efa2daf5c9471891e493c08961`; its ADC row predates the fix above. The census files are [result-census6.md](result-census6.md) and [result-census6.json](result-census6.json).

Later one-core Claude reruns, on a different engine image, reported `flash_ctrl` **DEBT** (0 hard errors, 11 semantic debts) and `otbn` **DEBT** (0 hard errors, one trace-checker warning); both reached `TEST PASSED CHECKS`. These do not form a replacement 49-core census.

Latest Claude gate records: JSON **4,438 run, 0 failed** and UVM **363 passed, 0 failed** at `2026-10-02T15:10Z`; the latest recorded legacy gate was earlier, **7,190 total, 0 failed** (7,185 passed, 2 not implemented, 3 expected-fail) at `2026-10-02T14:12Z`. They reflect Claude's evolving branch, not this rebuilt ADC image.

No coherent 49-core matrix has been run on the current ADC-fixed image. The mixed full-census and later targeted results must not be presented as a same-image 49-core status.
