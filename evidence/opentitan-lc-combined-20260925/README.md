# OpenTitan lc_ctrl smoke on Icarus: combined integration image

**Result:** `lc_ctrl_base_test` / `lc_ctrl_smoke_vseq` **passes**, 1/1.

- All 18 transition sequences complete.
- UVM report counts: `UVM_WARNING 0`, `UVM_ERROR 0`, `UVM_FATAL 0`.
- `TEST PASSED CHECKS`; `$finish` at 209,316,838 ps.
- The simulator exits with status 0.

This is **nonstandard compatibility** evidence: the compile uses `-gcommercial-unsafe`. It is one smoke test with the default seed, not a full lc_ctrl DV qualification. The compile still warns that `lc_ctrl_errors_vseq::invalid_states_bin_c` is not representable. That class is not used by the smoke test; #384 makes the constraint representable.

## Sources

- OpenTitan Earlgrey-PROD-M6, `a78922f14a8cc20c7ee569f322a04626f2ac6127`, unmodified. The FuseSoC build tree is `/private/tmp/ot-lc-packed-coverpoint-20260925/matrix-final/runtime/lowrisc_dv_lc_ctrl_sim_0.1`. Sampled files, including `lc_ctrl_smoke_vseq.sv`, `lc_ctrl_base_vseq.sv` and `lc_ctrl_fsm.sv`, are byte-identical to the pin.
- UVM 1.2 from `iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src`.
- No source overlay or patch is applied.

## Compiler

The integration branch `agent/ot-lc-combined-integration-20260925` is at `d16843457`. It merges these open PRs onto `main`:

| PR | Fix |
| --- | --- |
| #376 | packed coverpoint bins (Codex) |
| #377 | paren-less `process::self` |
| #378 | `disable` of an inherited task |
| #381 | `vif.modport` l-values |
| #382 | clocking outputs onto nets |
| #383 | wide constraint values, enum domains, queue-valued `inside`, function-return randomize |
| `agent/port-var-glitch-filter-20260926` | settled values across comb-variable port connections |
| `agent/nested-block-break-continue-20260926` | break/continue out of blocks with locals |

Its port-sampling commit carries the narrowed version (`cfb82fdb8`).

SHA-256 of the installed tools:

| Tool | SHA-256 |
| --- | --- |
| `lib/ivl/ivl` | `a29cb82755b99626ba3399811f82055e2d54963d95d40f8f1a18edb380803c0c` |
| `bin/vvp` | `687a2371aeedb05659f0627706867d770c648eaa8c3b27656c8b4253fd431af9` |
| `lib/ivl/vvp.tgt` | `a49e5b4edfcfacd3994fa9028a2873036c4ffbd04c1a5a695acbcf43c626c847` |
| `bin/iverilog` | `27a78fc6e1280e6b278291c22811f023f6ce2a0d61a58934b74e617f6879cb9f` |
| `lc_ctrl_flow.vvp` | `ddc019c754065f78722cfa2ebf01d7e6a345f306b68a0cd648dd057755357ec4` |

## Commands

Compile, run from `sim-icarus` in the build tree:

```sh
iverilog -g2012 -stb -slc_ctrl_bind -slc_ctrl_cov_bind -ssec_cm_prim_count_bind \
  -ssec_cm_prim_double_lfsr_bind -ssec_cm_prim_onehot_check_bind \
  -ssec_cm_prim_sparse_fsm_flop_bind -gcommercial-unsafe -uvm -DUVM -DUVM_NO_DEPRECATED \
  -DUVM_REG_ADDR_WIDTH=32 -DUVM_REG_DATA_WIDTH=64 -DUVM_REG_BYTENABLE_WIDTH=8 \
  -DUVM_REGEX_NO_DPI -DSIMULATION -DDUT_HIER=tb.dut -DSEC_VOLATILE_RAW_UNLOCK_EN=0 \
  --uvm-home=<uvm-1.2/src> -o lc_ctrl_flow.vvp -c ../matrix-iverilog.scr
```

`UVM_REG_DATA_WIDTH=64` and `UVM_REG_BYTENABLE_WIDTH=8` are the released dvsim values: `lc_ctrl_base_sim_cfg.hjson` overrides `tl_dw`/`tl_dbw`. The matrix harness hardcoded 32/4; #380 fixes that.

Run:

```sh
vvp -n lc_ctrl_flow.vvp +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_MEDIUM \
  +cdc_instrumentation_enabled=1 +smoke_test=1 \
  +UVM_TESTNAME=lc_ctrl_base_test +UVM_TEST_SEQ=lc_ctrl_smoke_vseq
```

The logs are `compile-flow.log` and `runtime-flow.log` (captured through a pseudo-tty); `runtime-flow.clean.log` is the same run with carriage returns stripped.

## What blocked the smoke, in order

1. **Harness width.** The register-model data width was 32, which caused a `UVM_FATAL` at the first 64-bit access (fixed in #380).
2. **Clocking output to a net.** A clocking output drove a concatenation-driven `wire` and aborted VVP (fixed in #382).
3. **Enum domain.** `std::randomize(lc_state)` produced a 320-bit value outside `lc_state_e`, and the DUT raised `fatal_state_error` (fixed in #383).
4. **Queue-valued `inside`.** `next_lc_state inside {VALID_NEXT_STATES[state]}` compared a one-bit value, so the test chose an illegal transition (fixed in #383).
5. **Port glitch loop.** A zero-delay loop between `u_lc_ctrl_fsm.p_fsm` and `p_csr_assign_inputs` through their ports grew past 80 GB and was killed by jetsam (exit 9). Fixed on the port-glitch branch.
6. **Function-return randomize.** `get_random_token()` returned an all-zero token, because `std::randomize` of a function's return variable was lost (fixed in #383).
7. **Nested `break`.** A `break` out of `while (1)` in `kmac_app_monitor` ended the monitor, so the token hash never got a response (fixed on the break/continue branch).

The probes used for diagnosis (`*_probe*.sv`) sit alongside these files.
