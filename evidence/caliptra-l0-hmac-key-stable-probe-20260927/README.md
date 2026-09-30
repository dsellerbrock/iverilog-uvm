# smoke_test_hmac: ERR_HMAC_KEY_NOT_STABLE root cause (2026-09-27)

In the 52-case sweep `caliptra-icarus-l0-main-52-20260926`, `smoke_test_hmac` fails. It exits 1 with 1 bad diagnostic:

```
hmac.sv:566: [CALIPTRA_ASSERT FAILED] ERR_HMAC_KEY_NOT_STABLE (hmac.sv:556)
```

The failure is at 760.885 us, in firmware's third flow, `hmac512_flow_csr`.

## Method

**Profile:** the same diagnostic profile as the sweep, with the identical compile command, file list (profile hash `72991e7c…`) and compiler:

| file | SHA-256 |
| --- | --- |
| ivl | `3fb64d55…` |
| vvp | `2401049a…` |
| vvp.tgt | `a49e5b4e…` |
| iverilog | `bd83f841…` |

**Probe:** `hmac_probe.sv` is a diagnostic-only observer, compiled as a second top-level module that drives nothing. For 745–761 us it prints on every HMAC clock edge:
- `PRE` values, via `$display` at the edge, which are the values the assertion samples;
- `POST` values, via `$strobe` at end of time step.

It covers `core_ready`, `ready_reg`, `CSR_MODE`, `init_reg` and `key_reg`.

**Run:** firmware `program.hex` is identical to the sweep run (SHA-256 `41399a07…`). No Caliptra or Adams Bridge source was modified.

## Observation (`run/sim.log`)

| edge | sampled (PRE) | after the edge (POST) |
| --- | --- | --- |
| 760875 ns (E0) | csr_mode=0 init=0 core_ready=1 key=12345678 | csr_mode=1 init=1 core_ready=1 key=0b0b0b0b |
| 760885 ns (E1) | csr_mode=1 init=1 core_ready=1 key=0b0b0b0b | (assertion fires first) |

**E0.** Firmware writes HMAC512_CTRL with INIT and CSR_MODE together (`hmac512_flow_csr`). `key_reg = CSR_MODE ? cptra_csr_hmac_key : HMAC512_KEY` is combinational (hmac.sv:304), so the key switches from the firmware key `0x12345678` to the SoC BFM's CSR key `0x0b0b0b0b` on this same edge.

**E1.** The core registers `init_cmd`, and `hmac_ctrl_reg` moves to IPAD. `core_ready` (combinational `ready_flag`) therefore falls in E1's NBA update.

## Analysis

The assertion is

```
assert property (@(posedge clk) disable iff ((!reset_n || core_ready) !== 0) $stable(key_reg))
```

At E1, `$stable(key_reg)` is false: the sampled key is `0b0b0b0b`, against `12345678` at E0.

IEEE 1800-2017 16.12 evaluates the `disable iff` condition on current, not sampled, values. The condition applies from the start of the attempt in the Observed region, which comes after NBA.
- At that point `core_ready` is already 0, so the attempt is not disabled, and it fails.
- A tool that evaluates the disable condition on the sampled value, `core_ready=1`, disables this attempt and passes.

**Conclusion:** Icarus's result is the IEEE 16.12 result for this RTL and firmware sequence. It is not a simulator defect. The test counts as a failure under the pass rule (zero assertion diagnostics). Weakening or patching the check would manufacture a pass, so no compatibility patch is proposed.
