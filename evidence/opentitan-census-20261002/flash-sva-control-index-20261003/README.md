# Flash runtime profile and SVA control index

This checkpoint follows the VVP `find_scope` cache documented in
`../flash-vpi-scope-cache-20261003/README.md`. It records what the native
Time Profiler run found, the narrow SVA lookup experiment, and the remaining
limits. It does not qualify the Flash census row.

## Findings

- The live-run investigation found the Flash VVP process CPU-bound (about 99%
  CPU at the observation point), not blocked in setup. An empty redirected log
  is expected while VVP buffers output: `vpi_printf` writes with `fputs` but
  does not flush. The wrapper's progress messages are separately flushed.
- A 1,200-second Flash replay with a 10,000,000,000-byte RSS cap is already
  recorded in the scope-cache checkpoint. It reached operation 2/3, used
  1,250,607,104 bytes peak RSS, and hit the wall cap without PASS or UVM
  error/fatal markers. A separate five-point `sample` profile captured
  phase-specific stacks through about 17 minutes.
- The 180-second macOS Time Profiler run used the scope-cached VVP and the
  indexed `system.vpi`. It yielded 56,982 VVP samples over about 178 seconds.
  Inclusive frame occurrence counts were: `find_scope` 13,543 (23.8%),
  `uvm_ivl_hdl_lookup_sel` 3,046 (5.35%), `vpi_handle_by_name` 3,033 (5.32%),
  `sva_enabled_calltf` 302 (0.53%), and `sva_kill_generation_calltf` 231
  (0.41%). `of_FORK` appears in 88.2% of stacks inclusively. Inclusive counts
  overlap and must not be summed. The largest self-time frames were allocator
  routines (`_xzm_free_main` 7.4%, `_xzm_xzone_malloc_tiny` 6.9%).
- This profile supports hierarchical VPI resolution and allocation/thread
  activity as remaining runtime costs. It does not show SVA control lookup as a
  large remaining cost after indexing. Because there is no same-phase Flash
  before/after profile, these data do not establish an end-to-end speedup.

## SVA lookup experiment

`vpi/sys_sva.c` now indexes assertion-control entries by `(scope, assertion
index)` using open addressing. The table stores entry indices so reallocating the
entry array does not invalidate the index. It resizes below a 50% load factor;
if allocation or capacity growth fails, it disables the index and retains the
linear lookup fallback. A 1,400-assertion regression exercises growth and
control behavior in both SystemVerilog 2017 and 2023. The focused VVP suite
passed 22/22 after the change.

A synthetic workload with 1,400 assertions and 1,000 cycles measured 3.070 s
average with linear lookup (two runs) and 1.951 s average with the index (two
runs), a 36.5% lower time / 1.57x speedup for that lookup-heavy fixture. This
is a microbenchmark result, not a Flash runtime result.

## Run limits and native-code assessment

The Time Profiler capture was capped at 180 seconds. Its wrapper recorded
`peak_vvp_rss_bytes=0`, so that capture does **not** demonstrate enforcement of
a 10 GB RSS cap. The independent 1,200-second replay above did enforce that RSS
cap. The instrumented replay reached the first erase scoreboard event at
18,945.4 ns, then stopped without a pass marker. No new 20-minute run was
needed: the existing 20-minute run and phase-spanning samples already establish
the CPU-bound behavior and later progress point.

The host VVP runtime and `system.vpi` are native ARM64 binaries built with
`-O2`; the testbench itself is VVP bytecode interpreted by `vvp`. Generic loop
unrolling is therefore not a direct way to compile the testbench's interpreted
work. Verilator can generate a native C++ model, but OpenTitan Flash/UVM
compatibility has not been established here. Callgrind is unavailable on this
ARM64 macOS host.

Raw Time Profiler artifacts remain in `/private/tmp/flash-sva-index-20261003/`
(`flash-time-profiler-elevated.trace`, `time-profile.xml`, and the run log). The
small synthetic SVA microbenchmark outputs remain in that directory as well.

The latest coherent census is still census11: 38 PASS, 7 DEBT, 1 compile
FAIL, 2 RUNTIME_FAIL, and 1 RUNTIME_TIMEOUT. The Flash row remains
unqualified.

References: [Icarus VVP engine](https://steveicarus.github.io/iverilog/developer/guide/vvp/vvp.html),
[Icarus VVP target](https://steveicarus.github.io/iverilog/targets/tgt-vvp.html),
[Verilator native binary generation](https://verilator.org/guide/latest/verilating.html),
and [Verilator language support](https://verilator.org/guide/latest/languages.html).
