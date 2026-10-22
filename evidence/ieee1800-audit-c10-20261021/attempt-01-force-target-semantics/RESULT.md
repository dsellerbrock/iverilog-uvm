# §10.6.2 force/release target semantics

## Basis and probes

IEEE 1800-2017 and 1800-2023 §10.6.2 permit force/release on a constant bit-select or constant part-select of a vector net, prohibit either select of a variable, and specify force/release behavior for variables. The paired probe in `input/p10_06_force_target_semantics.sv` checks net bit/part-select force and restoration, plus a forced variable overriding a procedural assignment and retaining its value after release until the next procedural assignment.

The existing standard-example probe `tests/1800_audit/c10/p10_06b_force_release.sv` and negative `tests/1800_audit/c10/neg/n10_06_force_var_bitsel.sv` were also rerun. The standard example covers a whole-variable force and whole-net force; the negative targets a bit-select of a variable.

## Current-head results

- Checkout: `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`; Mac ARM64.
- Built from this checkout with Homebrew Bison first in `PATH`: `make -j3` under `~/codex-supervisor/localrun 1200`, 67.30 s, peak RSS 910,082,048 bytes. Installed outside the checkout with `make install -j3 prefix=/tmp/a3-ieee1800-c10-20261021-install` under `localrun 300`.
- Icarus/VVP: 13.0 devel (`9bd5082b8`); SHA-256 `iverilog` `b92ded447f28bda589f2eac77ea4ec09115687286bb69ada09e3e3a6b14882fc`, `vvp` `22dae2c8cc68f40455ded0f7d66a7a0700f784223b840c4fa3212700c28abc94`.
- Each source was compiled with `-g2017` and `-g2023`, then run when compilation succeeded. Each compiler/simulator subprocess had a 30-second Python timeout; all were wrapped by `localrun`.
- New force-target probe: compile/run exit 0 in both editions; `RESULT checks=7 failures=0`. Constant bit/part-select force on a vector net and variable force/release behavior match the checked expectations.
- Standard example: compile/run exit 0 in both editions. Observed `d=x,e=0`, `d=1,e=1`, `d=x,e=0` at times 0/10/20; the standard expects `d=0,1,0` and `e=0,1,0`. This reproduces existing #768's procedural continuous-assignment RHS gap.
- Variable bit-select force negative: compilation succeeds in both editions, contrary to §10.6.2. This is already covered by #769; no new issue is proposed.

Raw compile/run logs and return codes are alongside this file under `current-head-check/`. Two initial compiler launches used an incorrect search root; their setup-only errors are preserved in `current-head-check/runner-path-error/` and `runner-layout-error/` and are not behavioral results. No issue was filed by A3.
