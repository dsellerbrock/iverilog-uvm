# OpenTitan native hot-path census 12

The full 49-target runtime census has completed. These findings come from
10-second macOS `sample` captures and Xcode Time Profiler captures of the native
ARM64 VVP process. The native-sample counts below are inclusive stack samples,
not exclusive CPU percentages or total-run fractions. Interpret each capture
as a snapshot of that test's current phase. New raw sample files are
gzip-compressed; recover one with `gzip -dc <capture.sample.txt.gz>`. The initial
full-matrix sampler produced 46 successful captures across 26 targets; the
Flash retry has its own additional captures. Short tests and unsampled runtime
phases are not covered.

## Ranked optimization candidates

This is a ranking by measured repeatability and apparent cost within captured
phases, not an aggregate ranking across all 49 tests. The profiles were taken
at different times and have different sample counts.

| Rank | Hot path | Evidence and scope | Candidate |
| --- | --- | --- | --- |
| 1 | Flash scoreboard associative-array successor walk | A separate five-hour Flash replay spent nearly all late samples in `of_AA_NEXT_SIG_V` / `compare_vec_keys_`; the exact-default retry also put 98.3% of its 4,500s sample in this path. The walk traverses a 262,144-entry scoreboard. | Replace repeated full-order successor searches with an order-aware traversal or iterator, preserving four-state key ordering. |
| 2 | Flash scoreboard population through backdoor reads | The default-args Flash Instruments capture has 2,471/30,355 stacks through `uvm_hdl_read`, 2,334 through `vpi_handle_by_name`, and 1,415 through `find_name`. Source walks 262,144 words; `read32()` issues four `read()`/`uvm_hdl_read()` calls per word. | Avoid redundant full-word backdoor reads and indexed path formatting across `read32()`'s four byte reads; reuse packed values only where Flash layout and ECC semantics permit. |
| 3 | Repeated Z3 domain/tuple enumeration | HMAC, I2C, TL-agent, ROM, SPI host/device, UART and other tests repeatedly sample `z3_enumerate_sparse_wide_domain_`; RV-DM has a distinct joint-tuple enumeration burst. | Reduce solver checks, model extraction and blocking-clause churn while preserving exact randomization semantics. |
| 4 | SRAM indexed backdoor name lookup | SRAM Time Profiler: 16,525/30,298 samples include `uvm_hdl_read`; 11,230 include `__vpiArray::get_word_str`, with 7,806 in `snprintf`. | Cache the resolved array base per scope/name and profile remaining path formatting and fallback scans. |
| 5 | SVA callbacks through VPI | Repeated `sva_enabled_calltf` / `sva_clock_calltf` and VPI argument, scope, iterator, get and put operations appear across ADC, entropy, OTP, PWM, reset, UART, system-reset and XBAR profiles. | Cache stable call-site argument and scope handles when callback lifetime rules permit. |
| 6 | Class-object alias and context/liveness bookkeeping | I2C 900s, Flash 1,800–2,700s and SPI host/device later-phase profiles show repeated context checks, alias notifications/copies and live-object checks. | Measure and reduce map/set probes and alias fanout costs without weakening lifetime or mutation-during-callback guarantees. |
| 7 | Four-state conversion and resolved-net propagation | Chip/XBAR and Alert Handler samples show repeated `reduce4`, `set_bit` and tri-net resolution; peripheral XBAR also has `set_bit` among its top leaves. | Optimize packed conversion/resolution while preserving X/Z and drive-strength semantics. |
| 8 | Virtual-interface slot resolution | KMAC 180s is dominated by `resolve_slots_`; EDN's 30s sample also shows this setup path. | Reduce repeated name/type/RTTI work during interface setup; this is a startup-only candidate. |
| 9 | Standard distribution randomization | Ibex icache has sustained `of_STD_RANDOMIZE_WITH` / `z3_resolve_dist_exact` samples at 30s and 180s. | Profile exact distribution handling separately from sparse-domain enumeration before changing it. |

The exact-default Flash retry has now reproduced that late phase, so it is not
specific to the separately seeded replay. Its 4,500s sample shows the
associative-array successor walk taking 98.3% of sampled stacks.

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

The TL-agent test stays solver dominated into its final phase: 5,734/6,801
stacks are under `randomize_with_` at 30s, and 5,776/6,869 at 180s. Sparse
enumeration contributes 3,090 and 3,058 stacks, respectively. Its base virtual
sequence randomizes host sequences for 100–200 requests, and `tl_host_seq`
randomizes each request with a delay constraint; this repeated workload matches
the persistent solver samples. TL-agent passed in 209.7 seconds.

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

ROM controller remains solver dominated at both 30s and 180s: 4,945/6,817 and
4,895/6,722 root stacks enter `randomize_with_`, including 2,645 and 2,687
sparse-domain enumeration stacks. Its config owns a randomized KMAC
application-agent config and a weighted delay constraint; these are
source-backed candidates, though the profile does not split costs by object or
constraint.

Profiles: [ROM controller at 30s](lowrisc_dv_rom_ctrl_sim_0.1-after-30s-pid19781.sample.txt)
and [180s](lowrisc_dv_rom_ctrl_sim_0.1-after-180s-pid19781.sample.txt).

RV-DM exposes a different randomization hot path. At 30s, all 7,159 root
stacks are inside `of_RANDOMIZE`; 3,712 reach `z3_enumerate_joint_()` and 2,114
reach `Z3_solver_get_model`. Unlike the sparse-wide helper above, the joint
helper enumerates complete tuples by checking the solver, extracting a model,
and adding a clause that blocks that tuple. Source candidates include the
randomized JTAG/SBA configs and `rv_dm_base_vseq`, which has several related
random flags and a weighted `tck_period_ps` distribution; the profile cannot
identify the specific randomize object. At 180s the profile has shifted to VPI:
1,603/7,079 roots enter `of_VPI_CALL`, including SVA callbacks. RV-DM passed in
211.7 seconds, so the solver burst is an early phase, followed by assertion
handling.

Profiles: [RV-DM at 30s](lowrisc_dv_rv_dm_sim_0.1-after-30s-pid20939.sample.txt)
and [180s](lowrisc_dv_rv_dm_sim_0.1-after-180s-pid20939.sample.txt).

SPI device flash-mode remains solver-heavy at both 30s and 180s: 4,925/6,698
and 2,687/6,932 roots are under `randomize_with_`, with 2,784 and 1,298 in
sparse-domain enumeration. Its sequence runs 1–12 transactions and calls
`randomize_op_addr_size()` for each; the inherited intercept sequence also
randomizes weighted access choices and delays in concurrent paths. This source
matches the sustained randomization samples, though the profile cannot assign
them to one individual callsite.

Profiles: [SPI device at 30s](lowrisc_dv_spi_device_sim_0.1-after-30s-pid21031.sample.txt),
[180s](lowrisc_dv_spi_device_sim_0.1-after-180s-pid21031.sample.txt), and
[900s](lowrisc_dv_spi_device_sim_0.1-after-900s-pid21031.sample.txt.gz).

The SPI host smoke sequence shows the same solver work in its early and later
phases. At 900s, 3,024/7,065 root stacks are under `randomize_with_`, with
1,701 in sparse-domain enumeration and 880 in model extraction. The direct
top-of-stack summary also records 746 automatic-context scope checks, 611
copies of the signal-alias vector, 443 alias notifications, and 378 live-object
checks. A 30.9-second Xcode Time Profiler capture during the later run resolved
all 30,297 sampled stacks: 13,394 include `randomize_with_`, 10,795 include
sparse-domain enumeration, and 7,899 include model extraction. Alias
notifications appear in 11,755 stacks, with 2,909 context checks and 2,025
live-object checks. These are inclusive stack counts, so paths overlap and the
counts are not exclusive CPU shares. The capture confirms both repeated
constraint solving and object/context bookkeeping remain after startup.

The same Time Profiler method was applied to SPI device during its later
phase. Of 30,422 sampled stacks, 9,730 include `randomize_with_`, 7,449
include sparse enumeration, and 5,005 include model extraction. Alias
notifications appear in 4,853 stacks. This agrees with its 30s, 180s, and 900s
native samples: sparse-domain Z3 enumeration is a sustained cost in both SPI
workloads, rather than just one setup burst.

Profiles: [SPI host at 30s](lowrisc_dv_spi_host_sim_1.0-after-30s-pid21719.sample.txt.gz),
[180s](lowrisc_dv_spi_host_sim_1.0-after-180s-pid21719.sample.txt.gz), and
[900s](lowrisc_dv_spi_host_sim_1.0-after-900s-pid21719.sample.txt.gz).

### SRAM indexed backdoor reads

SRAM controller has a distinct lookup bottleneck. At 180s, 3,523/6,490 root
stacks are in `uvm_hdl_read()` through the DPI/VPI name-lookup path. A
30.9-second Xcode Time Profiler capture later in the same run confirms the
phase's scale: 16,525/30,298 sampled stacks include `uvm_hdl_read()`, and
11,230 include `__vpiArray::get_word_str()` and its `snprintf()` work (7,806
stacks). These counts overlap and are not exclusive CPU shares.

The OpenTitan `mem_bkdr_util.read()` implementation forms a fresh
`path[index]` string for each memory read (`mem_bkdr_util.sv:227`). The active
VVP source includes the indexed-name fast path added in `70580fdaf`: it parses
the index, resolves the parent array, then calls `vpi_handle_by_index()` rather
than formatting every word name in the requested array. Locating that parent
still calls `find_name(base, scope)` (`vvp/vpi_priv.cc:1466`); this can walk
earlier scope objects and their memory words, and a failed fast-path lookup
can use the literal-name fallback. `__vpiArray::get_word_str()` in
`vvp/array.cc:496` formats names in those scans. The SRAM profile's repeated
`get_word_str()` samples therefore identify residual lookup work, not proof
that numeric-index resolution is missing. The hierarchical scope cache
(`a2df10e40`) caches scope transitions but not the final array-base handle.
Caching that base or reducing repeated path-string construction remains a
candidate; measure the fast path and fallback separately before changing it.

Profiles: [SRAM controller at 30s](lowrisc_dv_sram_ctrl_sim_0.1-after-30s-pid23604.sample.txt.gz)
and [180s](lowrisc_dv_sram_ctrl_sim_0.1-after-180s-pid23604.sample.txt.gz).

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

Ordinary interpreter and vector-stack work is also visible across profiles.
Peripheral XBAR's 30s top leaves include `of_STORE_VEC4` (286 samples),
`vthread_run` (273), `vvp_wire_vec4::vec4_value` (262),
`vthread_s::push_vec4` (253), `of_LOAD_VEC4` (243), and
`of_FLAG_SET_VEC4` (242). Similar instruction handlers recur in RV-DM, UART,
ADC, and OTBN. These are common VVP execution costs rather than one isolated
algorithm; the captures do not justify a broad interpreter rewrite by
themselves. The resolver's repeated bit conversion above is the more specific
vector optimization target.

The Earlgrey alert-handler smoke test repeats this four-state resolver path at
180s: 2,369/7,170 root stacks enter `vvp_fun_part_pv` and tri-net resolution;
the flat top-of-stack summary contains 1,940 `set_bit` and 993 `reduce4`
samples. Together with chip/XBAR, this makes four-state vector conversion a
cross-test candidate when wide resolved buses are active, not a universal
cost across the suite.

Profiles: [alert handler at 180s](lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1-after-180s-pid26640.sample.txt.gz)
and [360s](lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1-after-360s-pid26640.sample.txt.gz).

### VPI and backdoor access

The entropy-source profile has 1,797/6,884 root stacks under `of_VPI_CALL`,
including `sva_enabled_calltf`; its other visible branches include 781
`randomize_with_` and 720 `uvm_hdl_read` stacks. OTP controller also shows
`of_VPI_CALL` in 1,481/6,814 root stacks at 30s, with repeated `sva_enabled_calltf`
and VPI iterator/get/put work. This reinforces the SVA callback path as a
cross-target hot spot. PWM repeats it at 30s: 2,507/6,878 stacks are under
`of_VPI_CALL`, with `sva_enabled_calltf` below that path. PWM passed in 74.5s.
Reset manager also has 1,101/4,385 samples under `of_VPI_CALL` at 30s, including
`sva_enabled_calltf`; its runtime was 41.1s.
The xPack-enabled OTBN retry passed in 136.9s; its 120s profile has 480/1,783
stacks under `of_VPI_CALL`, with repeated SVA argument/scope access and
`vpi_get_value`/`vpi_put_value` work.
The Earlgrey main-XBAR test adds a clock-callback variation: 1,940/6,425 stacks
are under `of_VPI_CALL`, including 133 under `sva_clock_calltf`; this helper
re-fetches its call argument and assertion scope through VPI on every callback.
At 180s, `of_VPI_CALL` remains at 1,965/6,362, including 127
`sva_enabled_calltf` stacks within the 1,267-stack VPI-helper branch.
Alert handler also shifts into this callback work: 952/7,170 roots enter VPI
calls at 180s, increasing to 1,506/7,095 at 360s; `sva_enabled_calltf` appears
131 times in the latter call tree. Its 360s flat top-of-stack summary records
740 `set_bit` and 255 `reduce4` samples, showing the SVA value path and
four-state resolver costs overlap in time.
The early Flash profile includes
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
in the sampled ADC, entropy-source, PWM, OTP, and 900s Flash phases.

Profiles: [entropy source](lowrisc_dv_entropy_src_sim_0.1-after-30s-pid9242.sample.txt),
[OTP controller](lowrisc_dv_otp_ctrl_sim_0.1-after-30s-pid16949.sample.txt),
[OTBN retry at 120s](lowrisc_dv_otbn_sim_0.1-after-120s-pid27972.sample.txt.gz),
[PWM](lowrisc_dv_pwm_sim_0.1-after-30s-pid19545.sample.txt),
[reset manager](lowrisc_dv_rstmgr_sim_0.1-after-30s-pid20865.sample.txt),
[Earlgrey main XBAR](lowrisc_dv_top_earlgrey_xbar_main_sim_0.1-after-30s-pid25546.sample.txt.gz),
[Flash at 30s](lowrisc_dv_flash_ctrl_sim_0.1-after-30s-pid9372.sample.txt), and
[CSRNG](lowrisc_dv_csrng_sim_0.1-after-30s-pid8923.sample.txt).

Three additional 30-second captures extend this path to UART, system-reset,
and peripheral-XBAR workloads. UART has 439/6,891 stacks under `of_VPI_CALL`,
including SVA enabled/clock/kill callbacks, alongside 3,520 stacks in
`randomize_with_` and 1,938 in sparse-domain enumeration. System-reset has
2,716/6,641 roots under `of_VPI_CALL`, with repeated enabled, clock, and kill
callbacks. Peripheral XBAR has 1,317/6,987 under `of_VPI_CALL` and 1,372 under
`randomize_with_`; its top leaves also include 101 live-object checks and 222
`set_bit` samples. This supports the cross-target callback pattern while
showing that the same tests can carry separate solver and object/vector costs.

Profiles: [UART](lowrisc_dv_uart_sim_0.1-after-30s-pid26408.sample.txt.gz),
[system-reset](lowrisc_dv_sysrst_ctrl_sim_0.1-after-30s-pid24865.sample.txt.gz),
and [peripheral XBAR](lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1-after-30s-pid26208.sample.txt.gz).

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
confirms the context/alias path from the I2C profile in a second workload. At
2,700s, Flash still has solver work (1,376/7,032 roots under randomization, 802
under sparse enumeration), VPI/SVA callbacks (1,343 roots under `of_VPI_CALL`),
and context/alias bookkeeping in the flat summary (488 context checks, 376 alias
vector copies, 334 notifications, and 321 object-liveness checks). The corpus
Flash run has not reached the late scoreboard associative-array scan seen in
the separate long Flash replay.

Profiles: [Flash at 180s](lowrisc_dv_flash_ctrl_sim_0.1-after-180s-pid9372.sample.txt),
[900s](lowrisc_dv_flash_ctrl_sim_0.1-after-900s-pid9372.sample.txt), and
[1,800s](lowrisc_dv_flash_ctrl_sim_0.1-after-1800s-pid9372.sample.txt) and
[2,700s](lowrisc_dv_flash_ctrl_sim_0.1-after-2700s-pid9372.sample.txt).

The exact-default-args five-hour retry has repeated backdoor reads in its 30s,
180s, 900s, and 1,800s captures. Its 30s sample has 1,292
`of_DPI_CALL_VEC4` stacks; 569 descend through `uvm_ivl_hdl_put()` and the VPI
name-lookup path, including 440 `vpi_handle_by_name` samples. At 180s the leaf
summary shifts to interpreter work, vector access, Z3, and object-context
checks; `context_live_matches_scope_` is the largest single VVP leaf at 51
samples. At 900s, 1,766/6,945 roots are under `of_DPI_CALL_VEC4`, including 645
through `uvm_hdl_read`, 483 `vpi_handle_by_name`, and 119 `find_name` samples.

At 1,800s, a 30.4-second Instruments Time Profiler capture has 2,471/30,355
stacks through `uvm_hdl_read`, 2,334 through `vpi_handle_by_name`, and 1,415
through `find_name`. Those are inclusive stack counts (8.1%, 7.7%, and 4.7% of
samples); paths overlap. Class-object work is also present but smaller in this
capture: 552 stacks include `context_live_matches_scope_`, 485 include
`pointer_is_live`, and 428 include `notify_signal_aliases`. Only 141 stacks
include `randomize_with_` and 110 include sparse-domain enumeration, so solver
work is not a leading path in this sampled phase. The most frequent sampled leaf
frames also include `dpi_call_common_` (2,631), allocator free/allocation paths
(2,321/2,150), `vvp_vector4_t::set_bit` (1,151), and C++ tree rebalancing (733).
Those allocation and tree samples fit the object/context bookkeeping activity,
but the sample alone does not attribute them to a single container. Neither
this capture nor the 1,800s native `sample` output contains the late
`of_AA_NEXT_SIG_V` scan.

The pinned OpenTitan source explains the repeated read workload:
`flash_ctrl_env_cfg::update_partition_mem_model()` iterates the data partition
for both banks and stores every `read32()` result in the scoreboard model. The
partition has 131,072 words per bank (262,144 total). In
`mem_bkdr_util.sv`, `read32()` composes two `read16()` calls; each `read16()`
composes two `read8()` calls; each `read8()` calls `read()`, which formats a
fresh indexed path and invokes `uvm_hdl_read()`. That is four full backdoor
lookups for each 32-bit model word, about 1,048,576 calls for this pass. VVP's
`find_name()` source scans scope objects by name, matching the sampled
`vpi_handle_by_name`/`find_name` path. This gives a concrete testbench/runtime
optimization target. Reusing a packed value must preserve the byte mapping and
Flash's 76/68 ECC layout. The profile does not establish that all of the time
in those stacks is spent in scope scanning.

At 900s, the default-args sample again shows backdoor/VPI activity: 1,766/6,945
root stacks are under `of_DPI_CALL_VEC4`, including 645 through `uvm_hdl_read`,
483 `vpi_handle_by_name`, and 119 `find_name` samples. Object-context and
liveness checks remain visible in the top-of-stack summary. This is a longer
phase sample than the 30s startup capture, and still has no visible
`of_AA_NEXT_SIG_V` scoreboard walk.

At 2,700s, the exact-default sample has 1,449/7,272 roots under
`randomize_with_`, including 799 under sparse-domain enumeration; 1,314 roots
are under `of_VPI_CALL`. These counts closely match the separately seeded
2,700s sample (1,376 randomization roots, 802 sparse-enumeration roots, and
1,343 VPI roots). The sampled solver, callback, and object-update workload is
therefore repeatable across these two Flash invocations. The late associative
array successor scan is still absent at this point in the default-args run.

At 3,600s, a 10-second native sample had 1,826/7,264 roots inside
`of_DPI_CALL_VEC4`; 678 include `uvm_hdl_read`, 511 include
`vpi_handle_by_name`, and 79 include `find_name`. The solver path had fallen
out of this snapshot, while `of_VPI_CALL` accounted for 220 roots. A subsequent
30.3-second Instruments capture resolved 30,348 samples and shows a phase
transition: 102 samples include `of_AA_NEXT_SIG_V` and 82 include
`compare_vec_keys_`; 35 include `uvm_hdl_read`, and none include
`randomize_with_` or sparse-domain enumeration. The successor traversal has
therefore just begun in the exact-default run at that point, occupying 0.34%
of this capture. At 4,500s the next native sample shows the sustained late
phase: 7,580/7,714 roots (98.3%) are under `of_AA_NEXT_SIG_V`, and 6,989/7,714
include `compare_vec_keys_`. Only 14 roots include `uvm_hdl_read`, and no
sampled roots enter randomization. The simulator's physical footprint was
933 MB (1.3 GB peak), far below the 9,536 MiB runner cap. The default-argument
run has now reproduced the late associative-array bottleneck from the seeded
replay. The Instruments trace and exported XML remain local because the bundle
records host environment metadata.
The 4,800s sample repeats the result five minutes later: 7,568/7,729 roots
(97.9%) remain under `of_AA_NEXT_SIG_V`, 6,971/7,729 include
`compare_vec_keys_`, and only 16 include `uvm_hdl_read`. This confirms the
successor-walk profile is sustained across multiple snapshots. At 5,400s,
7,500/7,665 roots (97.8%) remain in the successor opcode and 6,754/7,665
include vector-key comparison; just 16 include `uvm_hdl_read`.

Profiles: [exact-default Flash at 30s](lowrisc_dv_flash_ctrl_sim_0.1-after-30s-pid28516.sample.txt.gz),
[180s](lowrisc_dv_flash_ctrl_sim_0.1-after-180s-pid28516.sample.txt.gz),
[900s](lowrisc_dv_flash_ctrl_sim_0.1-after-900s-pid28516.sample.txt.gz),
[1,800s](lowrisc_dv_flash_ctrl_sim_0.1-after-1800s-pid28516.sample.txt.gz),
[2,700s](lowrisc_dv_flash_ctrl_sim_0.1-after-2700s-pid28516.sample.txt.gz),
[3,600s](lowrisc_dv_flash_ctrl_sim_0.1-after-3600s-pid28516.sample.txt.gz),
[4,500s](lowrisc_dv_flash_ctrl_sim_0.1-after-4500s-pid28516.sample.txt.gz), and
[4,800s](lowrisc_dv_flash_ctrl_sim_0.1-after-4800s-pid28516.sample.txt.gz), and
[5,400s](lowrisc_dv_flash_ctrl_sim_0.1-after-5400s-pid28516.sample.txt.gz).
Earlier Instruments captures are retained locally under `/private/tmp`; they
are not included in the repository because trace bundles include host
environment metadata.

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

The earlier five-hour-capped Flash replay used an explicit seed and completed
in 5,349.4 seconds. Its early samples show solver and VPI/SVA phases, while
repeated late samples show the scoreboard memory walk spending nearly all
sampled stacks in vector-key associative-array successor search. That
source-confirmed O(N²) traversal is currently the strongest Flash optimization
target. `aa_next_signal()` calls the vector-key `next_key_()` for each
successor (`vvp/vthread.cc:21846-21855`); that overload scans the whole backing
map and compares vector keys to find the least key greater than the current
one (`vvp/vvp_assoc.h:642-660`). Walking 262,144 scoreboard entries therefore
visits the full map once per key, giving quadratic work. Any replacement needs
to preserve four-state key order. Details and late profiles are in
[the Flash replay record](../flash-5h-user-directed-20261003/README.md).

## Native execution boundary

The Xcode Time Profiler traces identify VVP as an ARM64 native process and
attribute samples directly to VVP C++ and `libz3`. The OpenTitan simulation
image itself is Icarus's compiled `.vvp` form, executed by the native VVP
runtime; the `vvp` man page describes that output as the runtime's default
compiled form, not a platform executable. This runner has no switch that
turns the SystemVerilog workload into native machine code. The viable native
optimization points are therefore the measured C++ runtime algorithms, VPI
paths, and Z3 integration.

## Census and profile coverage

The complete 49-target matrix finished with 45 PASS and four non-pass rows:
Flash runtime timeout at 3,000s, OTBN pre-run failure, OTP semantic debt, and
SPI-TPM compile failure. A focused OTBN retry with the installed xPack RISC-V
assembler and linker passed in 136.9s; its profile is included above. The exact
default-args Flash retry is now running with an 18,000s timeout and a 9,536 MiB
memory cap. Its result will replace the matrix's 3,000s timeout row in the
consolidated census if it completes successfully.

Profiles were captured at 30s, 180s, and 900s for VVP jobs lasting long enough,
with additional later Flash and alert-handler samples. Jobs that finish before
30s have no runtime sample, so the report makes no hot-path claim for them.
