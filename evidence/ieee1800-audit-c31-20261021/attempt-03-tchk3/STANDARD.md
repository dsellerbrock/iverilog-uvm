# IEEE basis and expected Clause 31 results

IEEE 1800-2017 and IEEE 1800-2023 were checked directly. Clause references and the relevant expected behavior are:

| Probe | Clause | Expected behavior |
|---|---|---|
| `$recrem` | §31.3.6 | A recovery violation for reset at t10 followed by clock at t11 with limit 3, and a removal violation for clock at t20 followed by reset at t21 with limit 2. |
| `$timeskew` | §31.4.2 | With 1 ns precision and limit 2, t43 is the first time step at which elapsed time exceeds the limit. A late data event at t43 cannot distinguish the default timer-based report from an event-based report. |
| `$fullskew` | §31.4.3 | With 1 ns precision and limit 2, the first time steps beyond the limit are t63 and t73 for the reference-first and data-first cases. These late events cannot distinguish the default timer-based mode from event-based reporting. |
| `edge [01]` | §31.5 | The 0→1 transition of `edge_clk` matches and reports a setup violation. The 0→x and x→1 transitions are excluded and do not add reports. |
| `&&&` conditioned event | §31.7 | A data event with `cond_en=1` is checked; a corresponding data event with `cond_en=0` is ignored. |
| vector data signal | §31.8 | A transition of one bit in a four-bit vector is one vector transition and produces one timing-check violation. |
| negative setup and explicit delayed signals | §31.9 and §31.9.1 | With setup −2 and hold 6, the data-stability window is (reference+2, reference+6), excluding endpoints. The model clocks `dd` on `posedge dclk`. In case A, data changes at reference+1, before the window, so the new stable value must be latched (`q=1`) and there is no violation. In case B, data changes at reference+4, inside the window, so the notifier changes once. No exact `dclk` or `dd` delay is assumed: §31.9.1 says delayed copies and adjusted limits are used, and requires the latched value to be stable during the violation window. |

The applicable text in §31.9 says negative values are accepted when the negative timing-check option is enabled. Section 31.9.1(a) excludes both window endpoints and says windows narrower than two precision units cannot produce violations. Section 31.9.1(b) requires the latched data value to be the value stable during the violation window. Example 1 in §31.9.1 says implicit delayed signals can clock the old data if it changes between the clock edge and the negative-setup interval. The probe therefore tests the required functional result rather than an implementation-specific delay allocation.

Expected positive-probe notifier total: 8 changes, final value 0. The separate no-data and late-data skew probe is required to distinguish default timer-based behavior from event-based behavior. Expected negative-probe output if negative checks are supported: `A q=1 nc=0`, then `B nc=1`.
