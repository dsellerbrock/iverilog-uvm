# Clause 12.5.1–12.5.3 current-head recheck

The existing paired `p12_05c_no_guards.sv` probe was rerun against checkout `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`, built on Mac ARM64 with Icarus/VVP 13.0 devel (`9bd5082b8`). Compile and run both exit 0 under `-g2017` and `-g2023`.

The combined probe reports `RESULT pass=12 fail=1` in both editions. The one failure is `match_cond`, the known §12.6.3 pattern-variable binding gap tracked by #781; it is not a §12.5 failure. The §12.5 cases pass: casez/casex do-not-care and ordered matching, the constant `case (1)` selector, and the tested `unique`/`unique0`/`priority` selection and warning behavior. Observed diagnostics are the expected no-match warnings for `unique`/uncovered `priority`, the overlap warning for `unique`, and silence for covered `priority` and unmatched `unique0`.

Each compiler and VVP subprocess had a 30-second Python timeout and was run under `~/codex-supervisor/localrun 180`. Raw per-edition logs and return codes are in this directory. The earlier search-root setup failures are preserved under `runner-path-error/` and `runner-layout-error/`; neither reached simulation and neither is a conformance result. No new issue was found or filed.
