# OpenTitan runtime matrix on main `4c45450a4`

This baseline follows merging PRs #376–#386, including the OpenTitan lc_ctrl campaign fixes. It is nonstandard compatibility evidence: every UVM compile uses `-gcommercial-unsafe`. A `DEBT` status means the run passed but its compile emitted degradation warnings; it is not a conformance pass.

## Inputs

- **OpenTitan:** Earlgrey-PROD-M6 `a78922f14a8cc20c7ee569f322a04626f2ac6127`, from `clean-corpora/opentitan-7a3ad34`. The checkout was verified at the pin and clean.
- **UVM:** 1.2, pinned.
- **FuseSoC:** `ot-0.5.dev0`, from `evidence/arm64-tooling/opentitan-python313`.
- **Harness:** `scripts/opentitan_matrix.py` at `4c45450a4`. It includes #380, so lc_ctrl, rv_dm and chip compile with `UVM_REG_DATA_WIDTH=64`.
- **Compiler:** a locked baseline worktree built at `4c45450a4`.

| Tool | SHA-256 |
| --- | --- |
| `lib/ivl/ivl` | `3fb64d5501f8928cbe02d5b9f6deabf4fd39956bd60ca4113931a1e822669a74` |
| `bin/vvp` | `99eaa1d6f3f6895aac94d561a40f8a8ce0f3da12c78d8f172e2c6f03c384c425` |
| `lib/ivl/vvp.tgt` | `a49e5b4edfcfacd3994fa9028a2873036c4ffbd04c1a5a695acbcf43c626c847` |
| `bin/iverilog` | `79c7b773ba48ccac64cb1f327478a2a53a68a9d9e39afc70cb5e49e931c446d9` |

Gates for the same build:

- Legacy ivtest: 6702 total, 6697 passed, 0 failed (2 not implemented, 3 expected fail).
- JSON/VVP: 3783 run, 0 failed.
- Real-DPI UVM: 358 passed, 0 failed, 0 skipped.

## Result

The matrix covered 49 runtime-lane cores: `DEBT=9`, `RUNTIME_FAIL=6`, `FAIL=34` (compile). The full table is in `result.md`, with per-core JSON in `result.json`.

| Core | Before, full unsafe run on 2026-09-25 | Now |
| --- | --- | --- |
| lc_ctrl | compile fail (4 errors) | **smoke passes** (DEBT) |
| tl_agent | compiled, no runtime | **smoke passes** (DEBT) |
| aon_timer, gpio, prim_alert, prim_esc, pwrmgr, xbar_main, xbar_peri | pass | pass (DEBT) |
| adc_ctrl, hmac, pattgen, prim_present, prim_prince, lowrisc_ip_trial1 | runtime fail | runtime fail |
| all others | compile fail | compile fail, with no new failure |

Runtime passes went from **7** to **9**, with no regression.

## Frontier notes

- **Upstream-invalid syntax.** Two compile-failure families are illegal SystemVerilog, and Icarus is right to reject them:
  - `static task` at module scope (4 spid cores); IEEE A.2.6 requires `task static`.
  - `import` directly inside a class body (2 cores).
- **Compile-progress warning in `DEBT`.** Most runtime passes carry `prim_onehot_check`'s `uwire ... has 31 drivers (compile-progress: treated as wire)` warning. The warning is spurious: disjoint continuous assignments to separate bits of one variable are legal. Removing it would turn those `DEBT` results into clean passes.
