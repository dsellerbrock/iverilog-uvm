# §26.2 package process probe

The §26.2 rule says package processes are limited to checkers; a standalone
`initial` process is therefore illegal. The same rule appears in IEEE
1800-2017 §26.2, p. 775, and IEEE 1800-2023 §26.2, p. 807.

## Probe and result

[`n26_02_initial_outside_checker.sv`](input/n26_02_initial_outside_checker.sv)
places an `initial` block directly in a package, with a top module as the
control context. On both `-g2017` and `-g2023`, Icarus rejected it at line 2
with `syntax error` and exit status 2, as expected. No simulation image was
produced. Raw compiler output is in the edition-specific `.compile.stdout` and
`.compile.stderr` files.

## Reproduction

- Host: macOS, Darwin 27.0, arm64.
- Source checkout: `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`.
- Build: `PATH=/opt/homebrew/opt/bison/bin:$PATH ~/codex-supervisor/localrun 1200 make -j3`; exit 0, 57.51 s, peak RSS 911,507,456 bytes.
- Installed compiler: Icarus Verilog 13.0-devel `9bd5082b8`, SHA-256 `b92ded447f28bda589f2eac77ea4ec09115687286bb69ada09e3e3a6b14882fc`.
- Edition commands, each run with a 30-second subprocess timeout inside `~/codex-supervisor/localrun 120 python3 -` from the repository root: `/tmp/a3-ieee1800-c26-20261021-install/bin/iverilog -g2017 -o evidence/ieee1800-audit-c26-20261021/attempt-01-package-process/2017.vvp evidence/ieee1800-audit-c26-20261021/attempt-01-package-process/input/n26_02_initial_outside_checker.sv` and the corresponding `-g2023` command/output path. Both returned 2; runner exit 0, 0.82 s total, peak RSS 17,448,960 bytes.

This confirms only the tested standalone-process rejection. No new issue candidate was observed.
