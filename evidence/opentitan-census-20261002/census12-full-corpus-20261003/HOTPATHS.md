# OpenTitan native hot-path census 12

The full 49-target runtime census is still running. These early findings come
from 10-second macOS `sample` captures of the native ARM64 VVP process. The
counts below are stack samples, not exclusive CPU percentages or total-run
fractions. Interpret each capture as a snapshot of that test's current phase.

## Confirmed paths so far

### Constraint solving

The ADC smoke test changes phase between setup and sequence execution. At 30
seconds, all 7,221 sampled stacks enter `of_RANDOMIZE` and Z3's optimize path,
including `maxcore::check_sat_hill_climb`. The test's generic
`dv_base_test::build_phase()` randomizes its environment `cfg`; the ADC config
contains nested filter arrays plus soft defaults and 24-bit/16-bit valid-value
ranges, making that config solve the leading source-backed candidate for the
startup cost. The sample does not identify the SystemVerilog class name, so the
exact randomize callsite remains an attribution rather than a profiler fact.

At 180 and 360 seconds, ADC's profile has shifted: `of_VPI_CALL` appears in
2,630/6,892 and 2,757/6,973 root stacks, while randomization is a small branch.
Those VPI branches include `sva_enabled_calltf`, `vpi_iterate`, `vpi_get_value`,
and `vpi_put_value`. The source callback in `vpi/sys_sva.c` retrieves its
argument and scope through VPI on every assertion check. This is a repeatable
steady-state path in the ADC samples, separate from the one-time Z3-heavy
startup phase.

Profiles: [ADC at 30s](lowrisc_dv_adc_ctrl_sim_0.1-after-30s-pid6448.sample.txt),
[180s](lowrisc_dv_adc_ctrl_sim_0.1-after-180s-pid6448.sample.txt), and
[360s](lowrisc_dv_adc_ctrl_sim_0.1-after-360s-pid6448.sample.txt).

### Four-state vector propagation

The chip test runs the OpenTitan XBAR smoke sequence. At 30 seconds, the
call tree is dominated by `vvp_fun_part_pv` and tri-net resolution; the flat
summary records 4,974 `vvp_vector4_t::set_bit` and 2,575 `reduce4` samples. At
180 seconds it records 4,682 and 2,806 respectively. `reduce4()` allocates a
packed four-state result, then converts each byte-sized eight-state input bit
with `value()` and `set_bit()`. The repeated per-bit conversion is a concrete
optimization candidate for this workload; any replacement must preserve X/Z
and drive-strength semantics at the resolver boundary.

Profiles: [chip/XBAR at 30s](lowrisc_dv_chip_sim_0.1-after-30s-pid7735.sample.txt)
and [180s](lowrisc_dv_chip_sim_0.1-after-180s-pid7735.sample.txt). The initial
sampler also captured the `iverilog` compiler waiting in `wait4`, not VVP; those
compiler-wait profiles are excluded from the runtime analysis.

### VPI and backdoor access

The entropy-source profile has 1,797/6,884 root stacks under `of_VPI_CALL`,
including `sva_enabled_calltf`; its other visible branches include 781
`randomize_with_` and 720 `uvm_hdl_read` stacks. The early Flash profile includes
`uvm_ivl_hdl_put`, `uvm_hdl_read`, `vpi_handle_by_name`, and `find_name` under
DPI calls. CSRNG also shows nested randomization/sparse-domain enumeration and
UVM HDL reads. These establish several workloads for checking whether the VPI
scope cache is effective end to end; the samples alone do not prove that cache
lookups are the dominant part of each test.

Profiles: [entropy source](lowrisc_dv_entropy_src_sim_0.1-after-30s-pid9242.sample.txt),
[Flash at 30s](lowrisc_dv_flash_ctrl_sim_0.1-after-30s-pid9372.sample.txt), and
[CSRNG](lowrisc_dv_csrng_sim_0.1-after-30s-pid8923.sample.txt).

### Virtual-interface startup

EDN's 30-second snapshot is dominated by `vvp_vinterface::resolve_slots_`,
`strdup`/`memmove`, and C++ RTTI casts while virtual-interface slots are being
resolved. This looks like a setup cost rather than a steady-state simulation
hot path; later captures will determine whether it persists.

Profile: [EDN](lowrisc_dv_edn_sim_0.1-after-30s-pid9179.sample.txt).

## Separate Flash replay

The five-hour-capped Flash replay completed cleanly in 5,349.4 seconds. Its early
samples show solver and VPI/SVA phases, while repeated late samples show the
scoreboard memory walk spending nearly all sampled stacks in vector-key
associative-array successor search. That source-confirmed O(N²) traversal is
currently the strongest Flash optimization target; details and late profiles
are in [the Flash replay record](../flash-5h-user-directed-20261003/README.md).

## Remaining work

The 49-target run is still in progress. This report will add profiles from the
longer SPI, I2C, SRAM, alert, and Flash runtime jobs, then rank shared and
test-specific hot paths against the completed runtime totals.
