# Issue #666 validation

Host: macOS. Local builds and test runs used `~/codex-supervisor/localrun`, with up to three build threads. UVM version: 2020.3.1 with real DPI for the focused UVM regression.

## Change

The specialization cache now resolves fully scoped integral constants and compares overrides against overridable formals only. A class-body `localparam` remains evaluated in the specialization, but no longer shifts positional formals or changes specialization identity. The regression checks that equivalent literal and scoped-localparam actuals cast to the same class type, a different actual remains distinct, and the derived `DATA_WIDTH` localparam evaluates to 32.

Design review checked the class-parameter and specialization rules in IEEE 1800-2017 §§6.18, 6.20.4, 6.22.1(c), 6.22.2, 6.24.2, 8.16 and 8.25.

## Evidence

- Baseline compiler from source commit `9b5fad2afb4104caa816b257d5bccc40f01b8c66`: exact A2 reproducer compiled and ran, factory wrappers matched, but both casts returned 0. Removing only the class `DATA_WIDTH` localparam made the alias cast return 1.
- Fixed compiler source: `cae035642e056644274a01e98d4422ce286685b4` plus this worktree's changes. `iverilog` SHA-256 `9bbf7f2bc039feb1f0463c3ece4665851478e524e6fba5a532afc53abb40f7b3`; `vvp` SHA-256 `ca1af64e88fe379e124367902d2f8390af6ba81a53b5abd75847055425b85801`.
- Build/install (`make -j3`, then `make install`): exit 0; 11.11 s; peak RSS 485,638,144 bytes.
- Exact issue reproducer, `iverilog -uvm -g2017 ...` and `iverilog -uvm -g2023 ...`, each followed by `vvp -n`: both editions exited 0 and printed `alias_wrapper_match=1 generated_wrapper_match=1 alias_cast=1 generated_cast=1`. Runtime 3.27 s / 3.57 s; peak RSS 265,535,488 / 263,766,016 bytes.
- Focused UVM regression: 1 passed, 0 failed, real DPI; 5.75 s; peak RSS 259,031,040 bytes.
- T0 `./ci/run-smoke.sh`: 133/133 passed; negative suite 152/152; runtime and malformed-input checks passed; exit 0; 168.45 s; peak RSS 116,654,080 bytes.
- `make -j3 check`: exit 0; 2.79 s; peak RSS 20,873,216 bytes.
- Graph-selected T1 `classes` area: 41/41 passed; 150.61 s; peak RSS 261,701,632 bytes.
- Review mutation check: inverted the localparam filter in `overridable_parameters_()` and rebuilt. The exact reproducer then failed during UVM elaboration (3 errors); the mutation was detected. Restored the source and rebuilt successfully (9.68 s; peak RSS 483,311,616 bytes).

The exact per-run logs and initial failing specialization traces are retained in this evidence directory for local review; the multi-megabyte debug traces are not part of the PR.
