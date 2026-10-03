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
