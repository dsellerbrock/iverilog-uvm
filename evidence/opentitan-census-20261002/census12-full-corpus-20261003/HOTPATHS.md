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

HMAC and I2C show a second, repeated randomization phase. HMAC has 2,913/6,979
root stacks under `randomize_with_` at 30s and 3,086/6,913 at 180s. I2C has
3,757/6,713 at 30s and 3,555/6,848 at 180s. In all four captures, the
`z3_enumerate_sparse_wide_domain_` descendant is prominent (1,444, 1,531,
1,983, and 1,882 root stacks respectively), followed by Z3 model construction.
The HMAC/I2C workload therefore remains solver-heavy after startup, rather than
showing only one large initial solve. These are stack shares, not exclusive CPU
percentages.

The key-manager 30s sample shows the same path at startup: 3,444/6,924 stacks
under `randomize_with_`, including 1,074 under sparse-domain enumeration; the
target passed in 56.2 seconds. KMAC also enters the same solver path (2,070/7,003
under `randomize_with_`, 574 under sparse enumeration). Its flat summary also
shows four-state conversion (`set_bit`: 828; `reduce4`: 379). These short
captures extend the solver pattern to both targets without establishing how
much of each complete run it occupies.

KMAC's 180s sample adds a separate virtual-interface setup burst: the call tree
has 2,286/6,456 stacks in `vvp_vinterface` construction and 1,773 inside
`resolve_slots_()`. That function allocates one slot per interface property,
looks up each named property in the VPI scope, and uses RTTI to classify arrays,
signals, reals, strings, and objects. The flat summary also has 748
`vpi_get_str`, 408 `strdup`, and 217 `memmove` samples, consistent with slot
resolution and name/type handling. This is a measurable setup path, but the
snapshot does not establish its share of total KMAC runtime. Solver work
persists in the same capture (791/6,456 `randomize_with_`, 465 sparse-domain
enumeration); four-state propagation remains visible (`set_bit`: 537,
`reduce4`: 306). The target completed in 416.0 seconds.

The helper at `vvp/vvp_z3.cc:7764` pushes the solver once, repeatedly checks it,
reads a model, and adds a constraint excluding that value, stopping after the
complete sparse set is found or its 64-value cap is exceeded. Repeated checks
and model construction are the concrete shared optimization target visible in
these profiles. The profiles do not yet identify which individual OpenTitan
constraint is responsible for most of the candidate set. The I2C sequence does
show repeated randomization in its source: `i2c_host_smoke_vseq` requests
50–100 transactions, and `i2c_rx_tx_vseq::host_send_trans` randomizes member
values in its per-transaction loop and uses constrained `fmt_item` randomize
calls. This explains why solver work can persist, but the profile cannot map
the Z3 samples to one particular source call.

The LC controller 30s profile adds another very solver-heavy startup workload:
4,352/6,755 root stacks enter `randomize_with_`, 4,349 enter the randomize graph,
and 2,218 reach sparse-domain enumeration; Z3 model construction is also
prominent. `lc_ctrl_env_cfg::initialize()` explicitly randomizes the OTP
push-pull, two alert/esc, JTAG, and KMAC agent configurations. The profile does
not attribute samples to one of those objects, so these calls are the
source-backed candidates rather than a per-object cost breakdown. The target
passed in 165.3 seconds, so this 30s snapshot captures startup but not its full
runtime.

Profile: [LC controller at 30s](lowrisc_dv_lc_ctrl_sim_0.1-after-30s-pid16253.sample.txt).

Profiles: [HMAC at 30s](lowrisc_dv_hmac_sim_0.1-after-30s-pid9607.sample.txt)
and [180s](lowrisc_dv_hmac_sim_0.1-after-180s-pid9607.sample.txt), [I2C at
30s](lowrisc_dv_i2c_sim_0.1-after-30s-pid10233.sample.txt) and
[180s](lowrisc_dv_i2c_sim_0.1-after-180s-pid10233.sample.txt), [keymgr at
30s](lowrisc_dv_keymgr_sim_0.1-after-30s-pid14610.sample.txt), and [KMAC at
30s](lowrisc_dv_kmac_sim_0.1-after-30s-pid14821.sample.txt) and [180s](lowrisc_dv_kmac_sim_0.1-after-180s-pid14821.sample.txt).

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

The active runner does include that cache: `/private/tmp/current-tools/bin/vvp`
is a symlink to this checkout's `vvp/vvp`, and the runtime SHA256 matches the
matrix fingerprint. In `vvp/vpi_priv.cc`, `find_scope()` caches successful
`(parent scope, child name)` resolutions and reuses them instead of rescanning
the parent's iterator; misses are not cached. `uvm_hdl_read()` reaches this
through `uvm_ivl_hdl_lookup()` → `vpi_handle_by_name()` for hierarchical paths.
The cache does not cache the final leaf `find_name()` lookup, and the samples do
not expose cache hit counts or a before/after speedup. They do show that the
repeated SVA callback work is a larger visible VPI path than scope resolution
in the sampled ADC, entropy-source, and 900s Flash phases.

Profiles: [entropy source](lowrisc_dv_entropy_src_sim_0.1-after-30s-pid9242.sample.txt),
[Flash at 30s](lowrisc_dv_flash_ctrl_sim_0.1-after-30s-pid9372.sample.txt), and
[CSRNG](lowrisc_dv_csrng_sim_0.1-after-30s-pid8923.sample.txt).

The two Flash captures show a phase change. At 30s, nested fork/DPI work is
prominent (`of_DPI_CALL_VEC4` → `dpi_call_common_` → `vvp_dpi_call` → `libffi`).
At 180s, 1,762/6,862 root stacks are under `randomize_with_`, including 993
under sparse-domain enumeration and 520 under `Z3_solver_get_model`. This is a
solver phase in the corpus smoke run. At 900s, the profile is split between
`of_VPI_CALL` (1,485/6,928) and `randomize_with_` (1,475/6,928), with 862
stacks in sparse-domain enumeration. At 1,800s, `randomize_with_` still appears
in 1,449/7,088 root stacks and `of_VPI_CALL` in 1,290/7,088. The top-of-stack
summary also shows the class-object context/alias path: 652 samples in
`context_live_matches_scope_`, 367 in copying the alias vector, 274 in
`notify_signal_aliases()`, and 223 in `vvp_object::pointer_is_live()`. This
confirms the context/alias path from the I2C profile in a second workload. The
corpus Flash run has not reached the late scoreboard associative-array scan
seen in the separate long Flash replay.

Profiles: [Flash at 180s](lowrisc_dv_flash_ctrl_sim_0.1-after-180s-pid9372.sample.txt),
[900s](lowrisc_dv_flash_ctrl_sim_0.1-after-900s-pid9372.sample.txt), and
[1,800s](lowrisc_dv_flash_ctrl_sim_0.1-after-1800s-pid9372.sample.txt).

The CSRNG 30s capture adds class-object and automatic-context bookkeeping to
the inventory. A repeated nested-fork path loads class signal objects through
`vvp_fun_signal_object_aa::get_root_net()` / `get_root_object()`, then
`vthread_get_rd_context_item_scoped()` and `first_live_context_for_scope()`.
The leaf summary also contains allocation/free, tree balancing, and object
liveness-check frames. This is a smaller secondary path in a single early
snapshot, not evidence that context tracking dominates the whole CSRNG run.
The same snapshot includes UVM HDL reads and randomization, so later captures
or targeted counts are needed before ranking those individual costs.

I2C's 900s sample gives stronger evidence for a related steady-state path:
1,067 top-of-stack samples are in `context_live_matches_scope_` and 431 in
`vvp_object::pointer_is_live`. The call tree ties these to class-object signal
updates (`of_STORE_PROP_V` → `notify_mutated_object_root_` →
`notify_signal_aliases` → `vvp_send_object` →
`vvp_fun_signal_object_aa::recv_object`). The scope-context check consults the
automatic-context owner map and live-context set; the object-liveness check
consults the live-object set. This is separate from the hierarchical VPI name
cache described above. It is a measured candidate, but this profile alone
cannot tell whether cheaper bookkeeping would preserve the required lifetime
and alias behavior.

Profile: [I2C at 900s](lowrisc_dv_i2c_sim_0.1-after-900s-pid10233.sample.txt).

At 1,800s, Flash shows the same class-object and automatic-context checks,
along with a vector copy on alias notification. In `vvp/vvp_object.cc`,
`notify_signal_aliases()` copies the alias set before iterating and sending
updates, so mutation during callback delivery does not invalidate the active
iteration. Treat the vector-copy count as part of that correctness-sensitive
fanout path; removing it would need its own safety argument and measurement.

### Other constrained-randomization path

The Ibex instruction-cache test uses the standard-randomize opcode: 1,468/6,887
root stacks are under `of_STD_RANDOMIZE_WITH` at 30s and 1,811/6,855 at 180s.
The path includes `vvp_z3_randomize_scope()` and `z3_resolve_dist_exact()`;
`Z3_solver_check` appears in 336 and 522 stacks respectively. The top-of-stack
lists also show Z3 AST-table setup and allocation. This distinct distribution-
sampling path persists beyond startup and is separate from sparse wide-domain
enumeration. The target passed in 223.7 seconds.

Profiles: [Ibex icache at 30s](lowrisc_dv_ibex_icache_sim_0.1-after-30s-pid13456.sample.txt)
and [180s](lowrisc_dv_ibex_icache_sim_0.1-after-180s-pid13456.sample.txt).

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

The 49-target run is still in progress. Continue capturing the longer SPI,
SRAM, alert, and remaining runtime jobs; then rank the measured shared and
test-specific paths against the completed runtime totals. The current report
does not claim exhaustive profile coverage for jobs that finish before the
sampler's 30-second threshold.
