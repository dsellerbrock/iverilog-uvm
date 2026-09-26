# OpenTitan LC_CTRL: paren-less `process::self` (2026-09-25)

Qualification: nonstandard compatibility (`-gcommercial-unsafe`, the matrix's
flag for every compile). Compile-only replay; LC_CTRL remains 0/1 released DV.

`lc_ctrl_errors_vseq.sv:795` calls `handle_alerts_process = process::self;`.
IEEE 1800-2017/2023 13.4.2 allows a zero-argument function call without
parentheses, but Icarus lowered only `process::self()`: the paren-less form
reached the scoped static-method rewrite in `PEIdent`, whose class resolver
has no scope for the built-in `process` class, and failed with
"Unable to bind variable `process.self'".

Replay of the unchanged matrix command on the pinned source tree
(`lowrisc_dv_lc_ctrl_sim_0.1`, same `matrix-iverilog.scr`):

| Build | Hard error sites |
|---|---|
| PR #376 image (`lc-ctrl-compile-before.log`) | 4: `run_clk_byp_rsp`, `run_flash_rma_rsp`, `tokens_a`, `process.self` |
| This branch (`lc-ctrl-compile.log`) | 3: `process.self` is gone |

This branch is based on `main` without PR #376, so the two dropped-bin
coverage diagnostics that PR removes are present again in this log.

Gates on the private build (`tool_hashes.txt`): legacy ivtest 6694 total,
6689 passed, 0 failed (2 not implemented, 3 expected fail); JSON/VVP 3747/0;
real-DPI UVM 358 passed, 0 failed, 0 skipped. Paired 2017/2023 regression
`sv_process_self_parenless` (plus a gold-checked unknown-member negative) is
RED on the prior image and GREEN here.
