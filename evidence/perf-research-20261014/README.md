# Performance research baseline (2026-10-14)

Measurements behind the [performance plan](../../docs/performance/PERFORMANCE_PLAN.md).
These results apply to one host and one revision. They do not show that any
optimization works; they show where current time goes.

## Provenance

| Item | Value |
| --- | --- |
| Revision | `5c7b3319` (`main` merge of PR #575), branch `claude/perf-optimization-research-om8110` |
| Host | Linux x86-64 container, 4 vCPU Intel Xeon @ 2.10 GHz, 15 GiB RAM |
| Toolchain | GCC 13.3.0, Bison (system), flex 2.6.4, Z3 4.8.12 (Ubuntu `libz3-dev`) |
| Build | `CFLAGS/CXXFLAGS="-g -O2 -fno-omit-frame-pointer" ./configure --prefix=$PWD/local-install`, `make -j4 install installuvm` |
| Profiler | `perf` 6.8 (`linux-tools-generic`), `perf record -F 2000 -g` |
| Workloads | `benchmarks/sim-hotspots/*.sv`, compiled as `run.sh` compiles them |
| Comparison | Verilator 5.020 (`apt`), `--binary --timing -O3` |

## Baseline wall times (single run, `vvp -n`)

| Workload | Wall | User | Max RSS | Notes |
| --- | ---: | ---: | ---: | --- |
| `rtl_pipe` | 1.20 s | 1.17 s | 13 MB | 128-stage continuous-assign + NBA pipeline |
| `rtl_alu` | 2.73 s | 2.68 s | 14 MB | 64 ALU lanes, muxes, compares |
| `behav` | 3.97 s | 3.94 s | 11 MB | automatic functions, loops, arrays |
| `classq` | 4.34 s | 4.23 s | 11 MB | classes, virtual methods, mailbox, queue |
| `randomize_z3` | 3.19 s | 3.09 s | 39 MB | `randomize()` through Z3 |
| `randomize_dv_txn` | 21.04 s | 20.72 s | 40 MB | 1,000 bus-transaction randomizations (21 ms per call) |
| `uvm_traffic` | 10.81 s | 10.54 s | 130 MB | UVM env, 5,000 items, real DPI |

Compile time: the UVM workload `iverilog` step takes 4.21 s and 266 MB and
emits a 34.6 MB text `.vvp` file. Loading that file (`compile_design`) takes
7.5% of the `uvm_traffic` run.

## Gap against a compiled simulator (RTL kernels only)

Verilator 5.020 compiled the two RTL benchmarks unchanged. Its output matched
Icarus exactly (`acc=46a3ed6e lfsr=b53dff5f`; `ra0=012329a4 rb0=0123299d
ra63=48d14de5 cnt5=ff`). At the original length it finished in under 10 ms,
so the run length was scaled 1000x for Verilator and 10x for an Icarus
linearity check:

| Kernel | Icarus per unit length | Verilator per unit length | Ratio |
| --- | ---: | ---: | ---: |
| `rtl_pipe` | 1.02-1.20 s (1x: 1.20 s; 10x: 10.18 s) | 4.42 ms (1000x: 4.42 s) | about 230-270x |
| `rtl_alu` | 2.73 s | 7.72 ms (1000x: 7.72 s) | about 350x |

Verilator is a 2-state, statically scheduled, cycle-based compiled simulator,
so this ratio is the upper bound of the gap, not a target for a 4-state
event-driven simulator. Published comparisons place commercial-class 4-state
compiled simulators at 35-45x faster than Icarus 10.0. See the CVC paper cited
in the plan.

## PGO experiment (no source changes)

A copy of `vvp/` was rebuilt with GCC `-fprofile-generate`, trained on
`rtl_pipe`, `rtl_alu`, `behav`, `classq`, `randomize_z3`, and `uvm_traffic`,
then rebuilt with `-fprofile-use -fprofile-correction`. Each figure is the
median of three runs, and every output was byte-identical to the baseline:

| Workload | Baseline | PGO | Speedup |
| --- | ---: | ---: | ---: |
| `rtl_pipe` | 1.155 s | 0.780 s | 1.47x |
| `rtl_alu` | 3.017 s | 1.916 s | 1.57x |
| `behav` | 3.166 s | 2.613 s | 1.21x |
| `classq` | 4.341 s | 3.777 s | 1.14x |
| `uvm_traffic` | 10.606 s | 9.928 s | 1.06x |

Caveats:
- The training set includes the measured workloads, so these are in-sample
  gains.
- The PGO build also omitted `-fno-omit-frame-pointer`.
- A held-out evaluation set and a frame-pointer-matched baseline are still
  required (WP2 in the plan).

## Profile summary

Full self-time and inclusive tables are in [profiles/](profiles/). Percentages
are perf samples for the whole run.

- **RTL (`rtl_pipe`, `rtl_alu`):** about 18-22% is net propagation:
  `vvp_net_t::send_vec4` (12.8% / 15.3%) and `vvp_wire_vec4::filter_vec4`
  (5.1% / 7.1%). About 10-13% is event-source transaction bookkeeping:
  `vvp_event_source_end`, `event_source_transaction_s::operator=`/`~`,
  `vvp_event_callback_begin`/`end`, and `flush_event_source_transaction_`.
  Scheduler, thread wake, `%load/vec4`, and `eeq` take the rest.
- **Behavioral (`behav`):** `of_CAST2` is 12.9% self time. It is a
  bit-by-bit 4-to-2-state loop (`vvp/vthread.cc` `of_CAST2`). Automatic-context
  resolution takes about 14%: `automatic_context_record_`,
  `resolve_context_scope`, `find_stacked_context_match_`,
  `context_live_matches_scope_`, and `vthread_get_rd_context_item_scoped`.
  `getenv` takes 2.4%: `vthread_run` calls `getenv("IVL_FUNC_TRACE")` each time
  a function thread pauses. `ctx_stats_bump` takes 1.2%.
- **Classes (`classq`):** object liveness, handle copy, and reset take about
  10%. `__dynamic_cast` plus the `strcmp` it does on type names takes about
  5-7%. `malloc`/`free` take about 7%.
- **UVM (`uvm_traffic`):** call and context machinery dominates. Inclusive:
  `do_fork_` 12.6%, `of_ALLOC` 10.1%, `do_join` 8.1%, `vthread_delete` 8.1%,
  `vthread_alloc_context` 7.3%, and `vthread_new_` 6.5%. Object signal-alias
  register, unregister, and notify take about 8%. `malloc`/`free` take about 13%
  inclusive. `__dynamic_cast` takes 5%. `std::set<vthread_s*>` and
  `std::map<object_mutation_key_t, ...>` tree operations take about 3%.
  `compile_design` (load) takes 7.5%.
- **Randomization (`randomize_dv_txn`):** 79% of samples are in `libz3`.
  Inclusive: `Z3_solver_check` 26.7%, `Z3_model_eval` 18.0%, and
  `Z3_mk_context` 12.7%. The interval sampler is 28.7% and
  `z3_isolated_count_exceeds_` is 23.4%. `libc` (allocation) is 17%.

## Reproduce

```sh
# from the repository root, after the build above
export PATH="$PWD/local-install/bin:$PATH"
W=$(mktemp -d); S=benchmarks/sim-hotspots; U=uvm-core/src
for n in rtl_pipe rtl_alu behav classq; do iverilog -g2012 -o $W/$n.vvp $S/$n.sv; done
for n in randomize_z3 randomize_dv_txn; do iverilog -g2017 -s main -o $W/$n.vvp $S/$n.sv; done
iverilog -g2012 -I $U -o $W/uvm_traffic.vvp $U/uvm_pkg.sv $S/uvm_traffic.sv
perf record -F 2000 -g -o $W/rtl_pipe.perf vvp -n $W/rtl_pipe.vvp
perf report -i $W/rtl_pipe.perf --no-children --stdio --sort symbol -g none | head -40
# uvm_traffic needs: vvp -n -d local-install/lib/ivl/uvm_dpi.vpi $W/uvm_traffic.vvp
```
