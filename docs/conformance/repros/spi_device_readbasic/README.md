# SPI Device `readbasic` zero-time loops

These small models isolate the two default-then-override combinational paths. Run each storm check twice: the original exits 1 after 100 events at one simulation time, and `-DPATCHED` exits 0. The two equivalence checks compare final four-state outputs.

```sh
iverilog -g2012 -s sram_mux_reducer -o /tmp/spid-mux.vvp sram_mux_storm_check.sv
vvp -n /tmp/spid-mux.vvp
iverilog -g2012 -DPATCHED -s sram_mux_reducer -o /tmp/spid-mux-fixed.vvp sram_mux_storm_check.sv
vvp -n /tmp/spid-mux-fixed.vvp
iverilog -g2012 -s sram_mux_branch_equiv -o /tmp/spid-mux-equiv.vvp sram_mux_branch_equiv.sv
vvp -n /tmp/spid-mux-equiv.vvp
iverilog -g2012 -s comb_feedback_unique_case_reducer -o /tmp/spid-cnt.vvp readcmd_storm_check.sv
vvp -n /tmp/spid-cnt.vvp
iverilog -g2012 -DPATCHED -s comb_feedback_unique_case_reducer -o /tmp/spid-cnt-fixed.vvp readcmd_storm_check.sv
vvp -n /tmp/spid-cnt-fixed.vvp
iverilog -g2012 -s readcmd_counter_branch_equiv -o /tmp/spid-cnt-equiv.vvp readcmd_counter_branch_equiv.sv
vvp -n /tmp/spid-cnt-equiv.vvp
```

The [selected copied-source replay](../../session_logs/2026-09-28_ot_spid_readbasic_patched_pass.json) passes with both named RTL patches. The pinned OpenTitan checkout is unchanged.
