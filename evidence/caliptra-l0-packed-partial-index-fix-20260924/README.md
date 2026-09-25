# Caliptra ERR_HWIF_IN root cause: partial packed index padding (2026-09-24)

Qualification: nonstandard compatibility (`-gcommercial-unsafe`), copied-source
diagnostic profile `diagnostic_reset_checker_source_ephemeral_jtag_port_overlay`.
Nothing here is a pristine or IEEE L0 result, and nothing here counts toward
the selected-52 denominator of the installed-tool sweep.

## Symptom

Five of six completed selected-52 diagnostic cases (`smoke_test_mbox`,
`_mbox_byte_read`, `_sha256`, `_sha512`, `_sha512_restore`) failed the
unchanged `soc_ifc_reg.sv` `ERR_HWIF_IN` assertion after ~18k trace commits.
An earlier probe isolated `CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.we = X`, fed by
`lsu_double_ecc_error_r = X` while `_m = 0`.

## Trace backward

1. All five failures stop within a few instructions of the released CRT
   `.data` copy loop exit (`bltu` at 0x82). The copy loop does only ROM loads
   and aligned DCCM stores, which never read DCCM. The first DCCM read of the
   run is `main`'s `lw` of `.data` (mbox: `0x5002007c`, bank 3). The passing
   `smoke_test_veer` does one DCCM load, of a word the core never wrote.
2. DCCM preload is clean: 0 X entries in all four banks after preload
   (`observer/v3_installed_partial_stdout.log`).
3. The bounded raw-port observer (`observer/caliptra_dccm_write_probe_v3b.sv`)
   shows the LSU computing `addr_bank[3]=2007` for the store to `0x2007c`,
   while the testbench RAM's bank-3 `ADR` port receives `xX00`. Bank 0 receives
   `0200` for index `0x2000` (`observer/v3b_installed_stdout.log`, 37 `xX00`
   bank-3 writes). Bank-3 writes go to `ram_core[X]` (dropped). The first
   bank-3 load reads an X address, so `rvecc_decode` yields a double error of X,
   which trips `ERR_HWIF_IN`. Other banks silently read the wrong index; veer's
   single bank-1 load of preloaded zeros passed only by coincidence.
4. `el2_mem_if.sv:46` declares `logic [N-1:0][17:4] dccm_addr_bank`.
   `el2_lsu_dccm_mem.sv:104-108` writes `dccm_mem_export.dccm_addr_bank[i]`
   from a per-bank `always_comb` through a modport.

## Minimal hypothesis and result

Hypothesis: Icarus mis-addresses an element select `m[i]` of a packed vector
whose inner dimension has a nonzero LSB when the select is a partial index
chain through the member/property l-value path.

`reducers/interface_dccm_addr_bank.sv` reproduces the exact top signature
(`ADR[3]=xX00`, banks 0-2 shifted) on the installed compiler in 2017/2023,
strict and unsafe: RED 4/4 (`reducers/installed_*.log`), GREEN 4/4 on the fix
(`reducers/private_*.log`). `write_path_isolation.sv` localizes it: modport
element writes are wrong, same-scope hierarchical writes and whole-vector
reads are correct, and an inner LSB of 0 is correct. `plain_variable_control.sv`
shows that plain module variables are unaffected.

Root cause: `netmisc.cc` `collapse_packed_member_indices()` padded the missing
trailing dimensions with literal index 0. The start of the remaining slice is
each trailing dimension's declared LSB (canonical offset 0), so writes and
reads landed `inner_lsb` bits low. Interface members through a modport, class
properties, and packed-struct members all use this helper.

Rejected hypotheses, kept as GREEN controls:
`reducers/rejected_bitflip_init.sv` (testbench error-injection register stays
known) and `reducers/rejected_same_edge_ordering.sv` (the pinned ICG, `rvdff`,
and RAM model sample `m` before a same-edge `Q <= 'x`).

## Pinned inputs

Caliptra v2.1.2 `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e` and Adams Bridge
`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`, both clean before and after every
run. No pinned file was edited; observers are separate root modules added to
copies of the profile.

## Tools

Installed tool (unchanged, reproduces the defect): ivl
`6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`, vvp
`e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`.
Private fixed build of this branch (never installed on the shared tool): see
`gates/tool_hashes.txt` (ivl `093c2620…`, vvp `5036ded7…`). Baseline: a locked,
detached worktree at `c5679aa31` built the same way (ivl `37f1af94…`).

## Gates (private fixed build versus the same-built baseline)

| Gate | Baseline c5679aa31 | Fix |
|---|---|---|
| Legacy ivtest | Total 6561, Passed 6556, Failed 0, NI 2, EF 3 | identical totals; identical non-pass set |
| JSON/VVP | Ran 3548, Failed 0 | Ran 3552 (+4 new), Failed 0 |
| Real-DPI UVM | — | 358 passed, 0 failed, 0 skipped (REAL DPI umbrella) |
| New paired test, 2017/2023 × strict/unsafe | RED on installed tool (18 checks) | 4/4 pass |

## Caliptra results (labels kept separate)

- **Pristine unsafe lane:** not rerun; it remains 0/1.
- **Strict conformance guard (private fix):** full-top compile exits 46; the log
  is byte-identical to `caliptra-icarus-l0-strict-p1-20260924/compile.log`.
- **Copied-source diagnostic unsafe compile (private fix):** compile log is
  byte-identical to the installed tool's (`45d926ac…`), with no new diagnostics.
- **Observer on the private fix:** bank 0 receives `2000, 2001, …` and the
  store to `0x2007c` reaches bank 3 at `ADR=2007`; zero `xX00` addresses
  (`observer/v3b_private_fix_stdout.log`).
- **Copied-source diagnostic profile, private fix, outside the installed-tool
  52 numerator:**
  - `smoke_test_veer`: PASS (`results/smoke_test_veer/`). Firmware and
    simulation exit 0, one pass marker, zero fail markers, zero bad
    diagnostics, 1033 retired instructions, 1034 trace commits. It now prints
    "Hello World from VeeR EL2 !!"; the installed-tool PASS retired only 633
    instructions because its `hw_data` read hit a wrong DCCM index and returned
    0, so it printed nothing.
  - `smoke_test_mbox`: no completed result. Two attempts were killed externally before
    `summary.json` (not by the runner's 14,400 s timeout). Something on the host
    kills processes whose command lines match this lane, which also took the
    observer waiters. The first attempt reached trace commit #20,425, past the
    old ERR_HWIF_IN point (#18,187), with zero fatal, error or ERR_HWIF_IN
    lines and the SoC mailbox read in progress
    (`results/smoke_test_mbox_partial_reaped/`). The second was killed at
    commit #59. This is not counted as a pass; a coordinator-scheduled rerun
    is requested in `tracker_proposal.md`.
