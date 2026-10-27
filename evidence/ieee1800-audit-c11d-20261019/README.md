# IEEE 1800 §11.6.2–§11.8.4 audit

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-19. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

`tests/1800_audit/c11/p11_06b_width_sign.sv` compiled and ran under `-g2017`
and `-g2023`, both producing `RESULT pass=17 fail=0`. It checks the standard's
context- and self-determined expression-size examples; signed/unsigned
arithmetic and casts; unsigned bit-select, part-select and concatenation
results; and X/Z sign fill and propagation. The exact runner, logs, and
localrun report are in `attempt-01-width-sign/` (`~/codex-supervisor/localrun
180 ...`, 0.37 s wall, 16,842,752 bytes peak RSS).

The tech lead classified §11.6.1–§11.6.3, §11.7, and §11.8.1–§11.8.4 as
IMPLEMENTED (tested subset). No new issue was filed from this tranche.
