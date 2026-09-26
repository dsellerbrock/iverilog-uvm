# Proposed tracker update for Codex: OpenTitan lc_ctrl

These are proposals only; no shared tracker, AGENTS.md or OpenTitan file was edited. Please integrate them into `.ai/ACTIVE_WORK.yaml`, `docs/conformance/CURRENT_WORK.md` and `docs/conformance/BLOCKERS.md` as you see fit.

## Status change

- **OpenTitan `lc_ctrl` (`lc_ctrl_base_test` / `lc_ctrl_smoke_vseq`, default seed):** was 0/1; now **1/1 passes** under nonstandard `-gcommercial-unsafe` on the integration image `agent/ot-lc-combined-integration-20260925@d16843457`.
- **Pass criteria met:** 18/18 sequences, `UVM_WARNING/ERROR/FATAL 0`, `TEST PASSED CHECKS`.
- **Sources:** pinned Earlgrey-PROD-M6, with no overlays.
- **Evidence:** `evidence/opentitan-lc-combined-20260925/README.md`, which lists the tool SHA-256s.
- **Scope:** this is not a full lc_ctrl DV qualification.

## PRs the pass depends on (all merged 2026-09-26 into main `4c45450a4`)

| PR | Fix | Gated (legacy / JSON / UVM) |
| --- | --- | --- |
| #376 | packed coverpoint bins (Codex) | per its own PR |
| #377 | paren-less `process::self` | 0 fail / 0 fail / 358 |
| #378 | `disable` of an inherited task | 0 / 0 / 358 |
| #380 | matrix harness: apply dvsim `tl_dw`/`tl_dbw` overrides (lc_ctrl, rv_dm and chip need `UVM_REG_DATA_WIDTH=64`) | script-only; verified on pinned configs |
| #381 | `vif.modport` l-values; stop silently dropping them | 0 / 0 / 358 |
| #382 | clocking outputs onto nets as resolved drivers | 0 / 0 / 358 |
| #383 | wide constraint values, enum domains, queue-valued `inside`, function-return randomize, statement-form scope randomize, wide diversity | 0 / 0 / 358 |
| #385 | settled values across comb-variable port connections (zero-delay FSM↔CSR loop) | 0 / 0 / 358 |
| #386 | break/continue out of blocks with their own variables | 0 / 0 / 358 |
| #384 | outside state in class constraints; unsupported items fail loudly (stacked on #383) | 0 / 0 / 358 |
| #379 | Caliptra evidence follow-up: qualified `smoke_test_mbox` pass | evidence only |

## Blockers to retire or reword

- **"lc_ctrl `fatal_state_error`":** the cause was `std::randomize` of a 320-bit enum ignoring the enum domain. Fixed in #383.
- **"lc_ctrl killed / reaper":** the smoke died with exit 9 from jetsam, not an external reaper. The runaway allocation came from the zero-delay port loop. Fixed in #385.
- **KMAC agent never answers:** a `break` out of `while (1)` in `kmac_app_monitor` ended the monitor thread. Fixed in #386. This may affect every KMAC-app DV environment: keymgr, rom_ctrl and chip.

## New findings to track

- **Harness width:** the matrix harness hardcoded `UVM_REG_DATA_WIDTH=32`/`BYTENABLE=4`. Codex's earlier lc_ctrl and rv_dm results used the wrong register width. #380 fixes this.
- **Unsupported constraint items:** with #384, the remaining ones fail at `randomize()` instead of being dropped. The full-matrix census counts 16 such items in 8 cores. Only `adc_ctrl` of those compiles today, and its smoke already fails (nested dynamic-array constraints).
- **Checkout drift:** the shared checkout `opentitan-upstream` sits at dev commit `7a3ad34b6d`, not the pin. The matrix build trees match the pin, so results stand, but read sources with `git show a78922f14:<path>`.

## Baseline after merging

The full unsafe matrix on main `4c45450a4` gives 9 runtime passes (DEBT), 6 runtime failures and 34 compile failures. Before this work it was 7 passes; lc_ctrl and tl_agent are new, and nothing regressed. The gates are legacy 0 failures, JSON 3783/0 and UVM 358/0. See `evidence/opentitan-main-census-4c45450a4/README.md`.
