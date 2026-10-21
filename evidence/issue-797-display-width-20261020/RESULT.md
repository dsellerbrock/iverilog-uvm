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

## T2 review correction — 2026-10-21

The first T2 batch exposed that the initial implementation changed
right-justified values to zero padding and left-justified values lost the
existing expression-width zeros. The paired tests now follow the explicit
examples in IEEE 1800-2017 §21.2.1.3 (pp. 629–630) and 1800-2023
§21.2.1.2 (pp. 658–659): `%3h` with `32'h5` is `005`, `%3h` with
`32'h1234` is `1234`, and
`%02X` with `32'h3` is `03`. Explicit field width suppresses automatic
expression-width zero extension, but never truncates significant digits.

The tests also retain a left-justified case for Icarus's existing formatting
extension, plus `$swrite` checks for the standard field padding. The legacy
`format` and `swrite` tests still expect space padding, so the source diff
changes those legacy outputs; their expected files have not been edited.
The first local T0 run passed before the `%02X` expectation was corrected;
it is superseded by the corrected run below.

## Corrected verification — 2026-10-21

- Host: Apple Silicon Mac, Apple clang 21. Source base `f5e2d1125` plus the
  four changed files in this worktree. Incremental `make -j1` and `make
  install` passed. The paired 2017/2023 legacy tests and JSON tests each pass
  2/2, individually guarded at 120 seconds. This corrected T0 run took 2.90
  seconds with 62,881,792 bytes maximum RSS.
- T1 smoke set: 56/56 passed. VPI: 133/133 passed. All smoke reproducers,
  negative tests, and VVP runtime checks passed. Display-focused T1: 23/25
  legacy cases passed; `format` and `swrite` fail only because their old
  output goldens expect spaces instead of the new radix zero-padding. The
  17 display-related JSON cases passed. The full local T1 command took 82.84
  seconds with 108,167,168 bytes maximum RSS.
- No existing golden was changed. T1 remains red pending a decision on the
  legacy output expectations; this branch is not ready-for-batch. The prior
  T2 staging gate also remains red, and no T2 rerun or merge was attempted.
- Raw T0/T1 runner output and the `format`/`swrite` mismatch logs are in
  `attempt-02-repair/` for local review; generated logs are not source files.
