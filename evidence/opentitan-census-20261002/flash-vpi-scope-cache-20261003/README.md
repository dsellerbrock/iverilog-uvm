# VPI hierarchical scope lookup cache

This follow-up targets the repeated `vpi_handle_by_name` → `find_scope` path
seen in the Flash runtime profile. `find_scope` now keeps successful
parent/name-to-child-scope resolutions for the simulation lifetime. It does
not cache misses or leaf-object handles.

## Evidence

- A standalone VPI benchmark builds 1,024 generate scopes and repeatedly looks
  up the last scope path 20,000 times in one simulation. Five sequential runs
  gave median CPU times of 0.503704 seconds with the pre-cache installed VVP
  and 0.004145 seconds with the rebuilt scope-cache VVP (about 122x faster for
  this deliberately scan-heavy workload).
- Nine focused VPI regressions passed with the scope-cache VVP: `by_name`,
  `static_class_storage`, `m12_nested_members`, `m12_lifetime`,
  `m12_sv_scopes`, `genblk_named`, `genblk_unnamed`, `genblk_direct`, and
  `scopes`.
- The bounded, non-instrumented Flash replay using the rebuilt VVP reached
  operation 1/3 and hit its 300-second wall-time cap without a PASS marker.
- A follow-up replay used a 1,200-second wall cap and a 10,000,000,000-byte RSS
  cap. It ended at the wall cap with wrapper `timed_out=true`, `returncode=0`,
  no memory-limit hit, and peak RSS 1,250,607,104 bytes. Its 3,666-byte log
  appeared after process exit; while VVP was running, the redirected log stayed
  empty. The last emitted marker starts operation 2/3 at 1,414,248.5 ns, then
  records a bank-1 Data-partition erase at 1,414,652.8 ns. There is no PASS,
  UVM_ERROR, or UVM_FATAL marker. The final simulation time is unknown because
  later output was not emitted before termination. The row remains unqualified.
- OpenTitan's published VCS report lists the smoke job at 5.131 minutes and
  11.250 ms simulated time. That is a different simulator/build and is context,
  not a direct performance comparison: [official Flash simulation report](https://reports.opentitan.org/hw/top_earlgrey/ip_autogen/flash_ctrl/dv/latest/report.html).

The synthetic benchmark therefore does not establish an end-to-end Flash
speedup or qualify the census row.

The captured sample points to this path as a substantial cost in the sampled
interval, but does not establish it as the sole runtime cause. Census11 remains
the latest coherent result at 38 PASS, 7 DEBT, 1 compile FAIL, 2 RUNTIME_FAIL,
and 1 RUNTIME_TIMEOUT.

## Reproduce the microbenchmark

From this directory, set `ROOT` to the active worktree root, then run:

```sh
"$ROOT/local-install/bin/iverilog-vpi" --name=scope_cache_bench scope_cache_bench.c
"$ROOT/local-install/bin/iverilog" -g2012 -L . -m scope_cache_bench -o bench.vvp bench.sv
"$ROOT/local-install/bin/vvp" bench.vvp
"$ROOT/vvp/vvp" bench.vvp
```

The first runtime is the pre-cache comparison binary; the last is the rebuilt
implementation. The source and benchmark design are preserved here. Temporary
plugin and VVP outputs are intentionally omitted.

The 20-minute replay's runner, result metadata, and captured output are also
preserved here as `run-flash-cache-1200s-10gb.py`,
`flash-1200s-10gb-result.json`, and `flash-1200s-10gb-20261003.log`.

## Five-point CPU profile

A second replay used the same cached VVP, runtime image, DPI library, source
tree, and test arguments. `stdbuf -oL -eL` made the redirected VVP log visible
while the process was active. The wrapper sampled the process for 10 seconds
at elapsed times near 2, 5, 9, 13, and 17 minutes. All five macOS `sample`
captures completed successfully. The wrapper source, progress stream, result
metadata, full log, and raw captures are preserved next to this file.

This replay hit the 1,200-second wall limit, not the 10,000,000,000-byte RSS
limit. Peak RSS was 1,330,036,736 bytes. The live log reached operation 2/3 at
1,414,248.5 ns and its bank-1 erase event at 1,414,652.8 ns. No later UVM
progress, PASS, UVM_ERROR, or UVM_FATAL was emitted before termination. The
wrapper's own return code was zero because it recorded the controlled timeout;
the Flash test remains unqualified.

The profile changes by phase:

- At 130, 310, and 550 seconds, `of_VPI_CALL` appears in roughly 30–32% of
  the main-thread sample stacks. The hottest named system-task frames are
  `sva_enabled_calltf` and `sva_kill_generation_calltf` from `vpi/sys_sva.c`.
  Those callbacks fetch their call/argument/scope handles and return values
  through the generic VPI API on repeated checker evaluations. The VVP thread
  interpreter and assertion work are both active; this is CPU work, not a
  stalled setup.
- At 791 seconds, forked UVM threads and DPI calls are more prominent. The
  sample includes `uvm_hdl_read` → `uvm_ivl_hdl_lookup_sel` →
  `vpi_handle_by_name`, plus VPI name traversal and frequent allocation/free
  work. `find_scope` is still present, but the repeated leaf-name lookup is
  outside the scope-only cache in `vvp/vpi_priv.cc`.
- At 1,031 seconds, VPI/SVA calls are again prominent. The test is still in
  operation 2/3, so a single static hotspot description would miss the phase
  change.

## Follow-up source inspection

The sampled SVA frames lead to `sva_enabled_calltf` and
`sva_kill_generation_calltf` in `vpi/sys_sva.c`. Both call
`sva_control_find_`, which linearly scans the registered assertion-control
entries for a matching `(scope, assertion index)`. This makes each callback's
lookup O(number of registered assertions). The profile identifies these
callbacks as frequent, but does not isolate the lookup's share from the VPI
handle and value operations around it; treat the scan as a measured-path
candidate, not a proven dominant cause.

Generic native loop unrolling is a weak first experiment here. The host VVP
and VPI code is already compiled with `-O2`, while the hot work is repeated
VPI callbacks and a data-dependent lookup loop. The testbench itself remains
VVP bytecode interpreted by `vvp`. A useful next comparison would measure
`sva_control_find_` across assertion-table sizes before considering an indexed
lookup, then check the same Flash phase under the same wall/RSS caps. No SVA
implementation change or new long replay was made for this source inspection.

One temporary UVM HDL parent-handle cache was already compared against the
baseline in a 100-second replay. Both reached operation 1/3 at 30,671 time
steps, and its isolated microbenchmarks improved by only about 1–2%, so that
cache was removed. The remaining measured-path candidates are the SVA control
entry scan described above and VPI leaf-name resolution during HDL reads; the
current samples do not establish either as the sole runtime cause. Any further
cache needs VPI lifetime checks and a same-workload before/after comparison.
The samples do not point to arithmetic loops as the main cost, so forcing more
loop unrolling is not the first thing to try.

The VVP runtime and `system.vpi` are already native code, built here with
`-O2`. The Icarus `-tvvp` target emits
VVP virtual-machine instructions, which `vvp` interprets; it has no built-in
native code-generation switch for this testbench. Verilator is installed here
as 5.051 and can generate and compile a C++ simulation binary, but a full
OpenTitan Flash/UVM compatibility run was not attempted. The repository's UVM
source reports version 2020.3.1; current Verilator documentation describes
UVM 2020.3.2 support while also documenting language limitations. Treat that
as a possible separate backend experiment, not a drop-in result.

Callgrind is not installed on this host. Upstream Valgrind's supported-platform
list covers ARM64/Linux and AMD64/macOS only through Ventura, not this ARM64
macOS 27 host, so the native `/usr/bin/sample` profiles are the appropriate
low-overhead call-graph evidence here.

References: [Icarus VVP engine](https://steveicarus.github.io/iverilog/developer/guide/vvp/vvp.html),
[Icarus VVP target](https://steveicarus.github.io/iverilog/targets/tgt-vvp.html),
[Verilator native binary generation](https://verilator.org/guide/latest/verilating.html),
[Verilator language limitations](https://verilator.org/guide/latest/languages.html),
[Valgrind supported platforms](https://valgrind.org/info/platforms.html), and
[Callgrind manual](https://valgrind.org/docs/manual/cl-manual.html).
