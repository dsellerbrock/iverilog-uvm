# IEEE 1800 §11.5–§11.6 audit

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-19. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
All successful outcomes matched under `-g2017` and `-g2023`.

## §11.5 operands, selects and array addressing

`p11_05a_select_len.sv` passes 13/13 in both editions. It covers constant and
variable bit/part selects, ascending-vector indexed selects, X and out-of-range
reads, out-of-range part-select writes, multidimensional unpacked indexing,
indirect memory indexing, and the §11.6 sizing cases. The only warning is the
expected 4-state result for the out-of-range `mem[9]` read. The four negative
cases all reject in both editions: reversed part-select, variable-bound
part-select, scalar bit-select and a range applied after three unpacked-array
indices. Commands, per-case logs and resource usage are in
`attempt-01-selects/` (localrun wall 1.20 s, peak RSS 17,039,360 bytes).

Closed #469 is related but covers two-state invalid-select result conversion,
not the tested 4-state and addressing rules here; its paired regressions are
already on main. The tech lead classified §11.5, §11.5.1 and §11.5.2 as
IMPLEMENTED (tested subset). §11.5.3 (longest static prefix) remains
UNASSESSED.

## §11.6 expression bit lengths

`p11_06b_width_sign.sv` passes 17/17 in both editions. It checks context-determined
conditional width, lost and retained carry, self-determined multiplication and
exponentiation, context-determined exponentiation, `$signed`/`$unsigned` and
cast behavior, signed and unsigned arithmetic, unsigned part/bit-select and
concatenation results, X/Z sign extension, and a nonlogical X result. The lead
classified §11.6.1–§11.6.3 IMPLEMENTED (tested subset); Table 11-21 is only
partly sampled. Logs and runner are in `../ieee1800-audit-c11d-20261019/attempt-01-width-sign/`
(wall 0.37 s, peak RSS 16,842,752 bytes).
