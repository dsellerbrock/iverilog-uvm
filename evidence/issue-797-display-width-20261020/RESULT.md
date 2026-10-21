# Issue #797: explicit radix field widths

## Standards

IEEE 1800-2017 §21.2.1.3, p. 629, and IEEE 1800-2023 §21.2.1.2 require
explicit widths to be minimum widths: hexadecimal, octal, and binary values
are zero-padded when short and expand without truncation when long.

## Baseline

- Source revision: `cc25756d187314742d347267c2a513b3e640a7fb`.
- Host: macOS 27.0, Apple Silicon arm64. Compiler: Icarus Verilog 13.0 devel.
- The paired 2017/2023 regression failed on the unmodified formatter. For
  `%3h|%3h|%3h|%02X|%3o|%3b|%h|%0h`, the output was
  `00000005|00000100|00001234|00000003|00000000005|00000000000000000000000000000101|00000005|5`.
  Both legacy and JSON focused runners failed in both editions.

## Fix and verification

`vpi/sys_display.c::get_format_char` now removes VPI's expression-width zero
extension when a radix field width is explicit, pads short values to that
minimum width, and leaves wider values intact. Automatic sizing without an
explicit width is unchanged.

- Focused issue tests: legacy 2/2 and JSON 2/2 passed for `-g2017` and
  `-g2023`.
- T1 display selection: legacy 10/10 and JSON 7/7 passed. It covers
  `$display`, `$fdisplay`, `$sformatf`, aggregate displays, nested display,
  and the new reducer.
- T1 selection followed the graph query for display/VPI formatting, then the
  source callers of `get_format` and `sys_display_calltf`; the graph had no
  direct path from that C helper to individual test nodes.
- T0 smoke: 56/56 smoke tests, 133/133 VPI tests, reproducer checks, negative
  tests, and VVP runtime checks passed via `ci/run-smoke.sh`.
- Commands (all in this worktree):
  - Build: `sh autoconf.sh`; `./configure --prefix=/tmp/a3-issue797-base-install --enable-libveriuser`; `make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex`; `make install`.
  - T0 focused: `PATH="$PWD/local-install/bin:$PATH" perl ./vvp_reg.pl regress-issue797-t0-legacy.list` and `PATH="$PWD/local-install/bin:$PATH" python3 ./vvp_reg.py regress-issue797-t0-vvp.list` — exit 0.
  - T1: `perl ./vvp_reg.pl regress-issue797-t1-legacy.list` and `python3 ./vvp_reg.py regress-issue797-t1-vvp.list` — exit 0.
  - Smoke: `PATH="$PWD/local-install/bin:$PATH" ci/run-smoke.sh` — exit 0.
- `git diff --check` — exit 0.
- All commands ran under `~/codex-supervisor/localrun` with serial builds.
  The resumed full build plus focused checks took 138.74 seconds; localrun
  reported 819,511,296 bytes maximum RSS. The final smoke/focused run took
  174.67 seconds; localrun reported 1,277,952 bytes maximum RSS.

The test sources use `PASSED` and reference the existing
`sv_const_string_format` golden, so this change adds no golden file or edits
an existing expected-output file.
