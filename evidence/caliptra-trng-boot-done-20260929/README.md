# TRNG boot-done timeout triage

The saved `smoke_test_trng` four-hour run timed out while firmware polled
entropy-source `DEBUG_STATUS` bit 17 at `0x200030d0`. Its `exec.log` has 789
zero reads from core cycle 60,531 to 71,562. Firmware enabled entropy near
cycle 57,654, so fewer than 14,000 enabled clocks had elapsed at timeout.

The pinned `physical_rng` testbench model (SHA-256
`85b73db47fdab769e55d8ca58c976a0cad68631d3f3eed0e7d13649c38abf01f`)
emits one valid four-bit sample every 500 clocks. The default entropy-source
bypass window needs 96 samples. The tiny `cadence.sv` control compiles and
runs against that unmodified model: its first 96 values match a diagnostic
DutyCycle=50 instance, while first-to-last valid spans are 47,500 and 4,750
clocks. `cadence.log` records the passing VVP result. Peak RSS was 6,668,288
bytes. The 48,000-clock estimate is a sampling lower bound, not a guaranteed
boot-done time; health tests and FIFO latency still matter.

Reproduce the model control with the installed Icarus tools and pinned source:

```sh
IVERILOG=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-caliptra-l0-20260924/local-install/bin/iverilog
VVP=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-caliptra-l0-20260924/local-install/bin/vvp
RNG=/Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl/src/entropy_src/tb/physical_rng.sv
"$IVERILOG" -g2017 -s tb -o /tmp/caliptra-trng-cadence.vvp "$RNG" cadence.sv
"$VVP" -n /tmp/caliptra-trng-cadence.vvp
```

After the live PV case exits, run one original-cadence `smoke_test_trng` with
an 8 GiB physical-footprint cap and 16-hour timeout. If bit 17 remains zero
after about 50,000 enabled clocks, passively probe RNG valid, bypass-window
count, main state, and debug-status data. Firmware compares the whole status
word to `0x20000`, so another set bit could also prolong its wait. No source
patch or additional historical 52-case PASS is claimed here.
