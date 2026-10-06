# OpenTitan hot-path reproducers

Bounded evidence probes for the paths in
[HOTPATHS.md](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md).
These are standalone fixtures, not full OpenTitan tests. `flash_aa_walk.sv`
calls VVP's actual associative-array `.first/.next` with the 32-bit packed
two-state `addr_t` key used by Earlgrey; `flash_aa_walk.cpp` compares the
ordering and alternative data structures independently of VVP.
See the [optimization plan](../../docs/conformance/opentitan_hotpath_optimization.md)
for candidate changes, risks, and correctness work.

The latest full selected-corpus result is
[49/49 after the vector-key index](../../evidence/opentitan-census-20261002/census14-post-vector-aa-index-20261004/README.md).
The isolated Flash before/after timings below use the same seven operations and
are distinct from the CPU-contended corpus timing.

The full-map scan is capped at 1,024 numeric keys because a 262,144-key scan
would require over 68 billion backing-entry visits. Ordered alternatives walk
the full 262,148-key C++ fixture.

## Toolchain and commands

Measurements used Apple ARM64 macOS 27.0:

| Tool | Version / fingerprint |
| --- | --- |
| Icarus engine | 13.0-devel, SHA-256 8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c |
| Icarus engine for indexed SV walk | 13.0-devel, SHA-256 02f5a2f162250fd33b2a7a3c22109fd66f047dd890caa58b5fe09a510a1785f1 |
| VVP runtime for the original probes | 13.0-devel, SHA-256 2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570 |
| VVP runtime for the indexed SV walk | 13.0-devel, SHA-256 105caac4cc9d56ddba0fdd08b4d7672735bcfdc4d2ad606e11790dc5d17315fe |
| Z3 shared library | 5.1.0, SHA-256 45344d6a38b6f75304433c2458d6fa16bc4907d426c96e2bedf0a90603460422 |
| C++ compiler | Apple clang 21.0.0 |

The original probes used `/private/tmp/current-tools`; their hashes are retained
above. The indexed SV walk used this checkout's ARM64 build after `make -j1`
and `make install`. To reproduce from this directory, set the tools to this
checkout's install prefix:

    IVERILOG=../../local-install/bin/iverilog
    VVP=../../local-install/bin/vvp
    IVERILOG_VPI=../../local-install/bin/iverilog-vpi

    clang++ -O2 -std=c++17 flash_aa_walk.cpp -o flash_aa_walk
    clang++ -O2 -std=c++17 $(pkg-config --cflags z3) z3_sparse_bench.cpp $(pkg-config --libs z3) -Wl,-rpath,/opt/homebrew/opt/z3/lib -o z3_sparse_bench
    clang++ -O2 -std=c++17 $(pkg-config --cflags z3) z3_joint_bench.cpp $(pkg-config --libs z3) -Wl,-rpath,/opt/homebrew/opt/z3/lib -o z3_joint_bench
    $IVERILOG_VPI --name=/tmp/flash_walk_timer flash_walk_timer.c
    $IVERILOG_VPI hdl_lookup_bench.c
    $IVERILOG_VPI sva_vpi_dispatch.c
    $IVERILOG -g2012 -s top -o flash_backdoor.vvp flash_backdoor.sv
    $IVERILOG -g2012 -s top -o flash_aa_walk.vvp flash_aa_walk.sv
    $IVERILOG -g2012 -s top -o flash_aa_semantics.vvp flash_aa_semantics.sv
    $IVERILOG -g2012 -s top -o sram_indexed_backdoor.vvp sram_indexed_backdoor.sv
    $IVERILOG -g2012 -s top -o vvp_sparse_randomize.vvp vvp_sparse_randomize.sv
    $IVERILOG -g2012 -s top -o vvp_joint_randomize.vvp vvp_joint_randomize.sv
    $IVERILOG -g2012 -s top -o four_state_resolution.vvp four_state_resolution.sv
    $IVERILOG -g2012 -s top -o class_context_liveness.vvp class_context_liveness.sv
    $IVERILOG -g2012 -s top -o virtual_interface_slots.vvp virtual_interface_slots.sv
    $IVERILOG -g2012 -s top -o standard_distribution.vvp standard_distribution.sv
    $IVERILOG -g2012 -s top -o sva_vpi_dispatch.vvp sva_vpi_dispatch.sv

    /usr/bin/time -lp ./flash_aa_walk 1024 262144
    /usr/bin/time -lp $VVP -M/tmp -mflash_walk_timer flash_aa_walk.vvp +entries=262144
    /usr/bin/time -lp $VVP -M/tmp -mflash_walk_timer flash_aa_walk.vvp +entries=4096
    $VVP flash_aa_semantics.vvp
    /usr/bin/time -lp $VVP vvp_sparse_randomize.vvp
    /usr/bin/time -lp $VVP vvp_joint_randomize.vvp
    /usr/bin/time -lp ./z3_sparse_bench spi 25
    /usr/bin/time -lp ./z3_sparse_bench i2c 25
    /usr/bin/time -lp ./z3_sparse_bench hmac 25
    /usr/bin/time -lp ./z3_sparse_bench tl 25
    /usr/bin/time -lp ./z3_joint_bench 25
    /usr/bin/time -lp $VVP -M. -mhdl_lookup_bench flash_backdoor.vvp
    /usr/bin/time -lp $VVP -M. -mhdl_lookup_bench sram_indexed_backdoor.vvp
    /usr/bin/time -lp $VVP four_state_resolution.vvp
    /usr/bin/time -lp $VVP class_context_liveness.vvp
    /usr/bin/time -lp $VVP virtual_interface_slots.vvp
    /usr/bin/time -lp $VVP standard_distribution.vvp
    /usr/bin/time -lp $VVP -M. -msva_vpi_dispatch sva_vpi_dispatch.vvp

The Z3 compile commands use Homebrew's macOS library path. Adjust that linker
path on other systems while keeping the same Z3 version for comparable timings.
The time command reports whole-process counters; C++ fixtures also report
operation-level timing.

## Results

The original fixture figures below are single runs. The new full-size VVP walk
is repeated three times. Fixture timings do not predict whole-corpus speedups.

### Flash associative-array successor walk

The timed SV fixture uses `bit [31:0]` keys, matching Earlgrey's
`typedef bit [TL_AW-1:0] addr_t` with `TL_AW=32`. It populates 262,144
contiguous addresses and checks every key and the final termination. The
separate C++ algorithm comparison uses the same 32-bit raw key width, with
numeric values 0 through 262,143 plus four four-state examples. It mirrors
`compare_vec_keys_` ordering: signed-negative split, sign extension, MSB-first
0 < 1 < X < Z, and width-prefixed raw-key tie-breaking. It passed 231,200
comparator-pair checks over every 1–4 bit 0/1/X/Z key in signed and unsigned
modes, plus 680 current-algorithm successor checks.

| Structure / walk | Build | Full walk | Counts and correctness |
| --- | ---: | ---: | --- |
| Current full-map scan, 1,024 numeric + 4 four-state keys | 0.173 ms | 40.143 ms | 1,028 successors; 1,057,812 entries scanned; 1,585,690 comparator calls |
| Ordered std::set, full corpus, upper_bound per successor | 302.992 ms | 200.472 ms | 262,148 successors; 262,149 queries; 7,209,116 comparator calls |
| Same ordered set, iterator stream | included above | 2.275 ms | 262,148 successors |
| unordered_map plus ordered set, upper_bound per successor | 373.169 ms | 290.878 ms | 262,148 successors and hash lookups; exact key/value matches |
| Same hash/index pair, iterator stream | included above | 40.252 ms | 262,148 successors and hash lookups |

The full-size scan is disabled; no full-scan duration or speedup ratio is
extrapolated. `upper_bound` models an independent next query at every step. The
iterator result is a streaming best case; a generic SV `next` implementation
must also observe intervening array mutations. The SV fixture populates a real
VVP associative array, then checks every key returned by `.first/.next` and
that traversal stops at the final key.

With the phase timer loaded, the indexed VVP runtime passed the 262,144-key
32-bit vector walk three times. Population took 240–289 ms (265 ms median),
`.first/.next` traversal took 1.330–1.579 s (1.444 s median), and whole-process
wall was 1.60–1.97 s (1.69 s median); maximum resident set size was 61.3 MB.
A focused 4,096-key run measured 4.468 ms for population and 20.772 ms for
traversal (0.03 s process wall). The phase figures include SV loop checks and
two VPI timer calls; they are not engine-only timings. The command used for the
full run is the exact invocation above. These numbers establish the current
vector-key fixture baseline, not a before-and-after ratio.

`flash_aa_semantics.sv` separately passes mutation checks (deleting the next
key, inserting after the cursor, then deleting the cursor key) and walks
four-state keys that differ at the same most-significant position in
`0 < 1 < X < Z` order. This small case establishes runtime semantics; it is
not included in the 262,144-key timing.

The same Flash image and DPI library, seed, and seven operation inputs were
then run once against each VVP runtime:

| Runtime | SHA-256 | Wall time | Peak RSS | Result |
| --- | --- | ---: | ---: | --- |
| Prior scan | `2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570` | 5,349.4 s | 1,748,877,312 bytes | [clean pass](../../evidence/opentitan-census-20261002/flash-5h-user-directed-20261003/result.json) |
| Ordered index | `105caac4cc9d56ddba0fdd08b4d7672735bcfdc4d2ad606e11790dc5d17315fe` | 3,338.4 s | 1,474,989,584 bytes | [clean pass](../../evidence/opentitan-census-20261002/flash-after-vector-aa-index-20261004/result.json) |

The indexed run was 37.6% shorter (1.60x elapsed-time speedup). Both runs
completed all seven operations with zero UVM errors or fatals and no timeout or
memory-cap hit. The old late-phase sample recorded `of_AA_NEXT_SIG_V` in
7,563 of 7,656 root stacks; the indexed-run capture recorded it in 106 of
5,758. These captures are qualitative phase snapshots, not CPU percentages,
and used different sampling windows: [old operation-4 capture](../../evidence/opentitan-census-20261002/flash-5h-user-directed-20261003/flash-sample-operation4-75m.txt),
[indexed capture](../../evidence/opentitan-census-20261002/flash-after-vector-aa-index-20261004/sample-during-ops-3-4.txt).

### Z3 sparse and joint enumeration

The C++ fixtures exercise check, model extraction, and blocker addition, then
verify unique complete enumeration. SPI/I2C/HMAC/TL inputs are synthetic domain
sizes, not extracted OpenTitan constraints.

| Case | Counters | Fixture elapsed |
| --- | --- | ---: |
| Sparse SPI analogue, 25 × 16 values | 425 checks, 400 models/blockers | 46.23 ms |
| Sparse I2C analogue, 25 × 12 | 325 checks, 300 models/blockers | 34.92 ms |
| Sparse HMAC analogue, 25 × 24 | 625 checks, 600 models/blockers | 65.39 ms |
| Sparse TL analogue, 25 × 32 | 825 checks, 800 models/blockers | 91.81 ms |
| RV-DM joint analogue, 25 × 32 three-variable tuples | 825 checks, 800 models/blockers | 155.92 ms |

The C++ fixtures reproduce the solver-call shape, not VVP's private
enumeration helpers, candidate domains, or model extraction costs. Two added
SystemVerilog fixtures exercise the actual VVP `std::randomize` route. The
sparse case randomizes a 32-bit value over eight explicit, widely spaced
candidates; with this width the bounded dense-domain paths decline and the
runtime dispatches to `z3_enumerate_sparse_wide_domain_`. The joint case
randomizes two fields in distinct child objects under a cross-object ordering
constraint; the object graph takes the `exact_joint` path and enumerates its
three legal tuples with `z3_enumerate_joint_`. These exercise the helper call
paths but do not extract constraints from OpenTitan sources, and the runtime
does not expose helper-level solver counters to these fixtures.

| VVP fixture | Seed and correctness | Process wall |
| --- | --- | ---: |
| Sparse wide domain | Seed 20261004; 64 draws stayed in the exact 8-value support; observed bins `{4,8,5,16,4,8,11,8}` | 1.22 s |
| Joint child-object tuple | Seed 20261004; 64 draws were among exactly `(0,2)`, `(0,5)`, `(2,5)`; all three appeared with bins `{28,20,16}` | 0.13 s |

These were run with the indexed VVP toolchain hashes in the table above. Each
fixture reports successful randomize calls and output bins; solver checks,
model extractions, and blocker counts are not instrumented. The C++ proxy
tables report explicit operation counts for algorithm-level comparison.

### VPI name lookup and backdoor reads

Both cases initialize and check 16,384 bytes through handles from census13 VVP.
The Flash-like fixture resolves full word names. The SRAM-like fixture resolves
top.mem once and then uses vpi_handle_by_index.

| Case | VPI operations | Plugin CPU / process wall |
| --- | --- | ---: |
| Full-name read32 analogue, 4,096 words | 16,384 name lookups + gets | 3.376 ms / 0.09 s |
| Indexed array read analogue | 1 base lookup + 16,384 indexed lookups + gets | 0.493 ms / <0.01 s |

The fixture does not include UVM's uvm_hdl_read wrapper, Flash ECC/packed
layout, or the full 262,144-word population loop.

### Other VVP paths

| Case | Correctness and counts | Process wall |
| --- | --- | ---: |
| Four-state resolution | 2,000 cycles; 8,000 X/Z checks | <0.01 s |
| Class aliases and automatic task context | 2,000 alias groups, updates, and checks | 0.01 s |
| Virtual-interface slots | 64 constructions; 3 members; 64 value checks | <0.01 s |
| Standard distribution randomization | Seed 20261004; 2,000 std::randomize calls; support checked; bins `{1:1241,2:525,8:63,9:39,10:45,11:87}` | 3.77 s |
| SVA helper/VPI dispatch | 1,000 $ivl_sva_enabled, $ivl_assert_clock, and value-change callbacks; 0 errors | 0.07 s |

These fixtures hit the relevant VVP syntax/runtime path, but do not expose
private counters for set_bit/reduce4, context-map/liveness probes, VIF slot
resolution, or assertion-object fanout. The distribution histogram is
reproducible for this runtime and seed; it checks support, not a frequency
guarantee.

## Ranked coverage map

This maps all nine rows in `HOTPATHS.md` to a focused invocation, correctness
oracle, reported metric, and the remaining reproduction gap. The direct VVP
operation fixtures isolate cost and semantics; only the Flash replay exercises
the full OpenTitan test. The optimization plan gives the first speedup
experiment, correctness gate, and measurement gate for every row.

| HOTPATHS rank and case | Exact invocation | Correctness oracle | Reported metric | Fidelity limit |
| --- | --- | --- | --- | --- |
| 1. Flash AA successor/comparator | `/usr/bin/time -lp $VVP -M/tmp -mflash_walk_timer flash_aa_walk.vvp +entries=262144`; `$VVP flash_aa_semantics.vvp`; `./flash_aa_walk 1024 262144` | Full SV walk checks each vector key and termination; semantics SV checks mutation and four-state order; C++ checks comparator pairs and successor sequence | Full-size wall/RSS above; phase split at 4,096; C++ build, walk, comparator and scan counts | Matches Earlgrey's 32-bit `bit` address key, but the timed fixture walks a one-dimensional AA; OpenTitan's error table is nested `[addr_t][flash_dv_part_e]`. The 262,144 contiguous addresses are synthetic and actual error-table cardinality is not extracted. Mixed widths and signed mode are C++ comparator cases, not the timed VVP case. Timer includes SV loop and VPI-call overhead. |
| 2. Flash full-name backdoor reads | `/usr/bin/time -lp $VVP -M. -mhdl_lookup_bench flash_backdoor.vvp` | Plugin checks every named handle/value while reconstructing 4,096 words | 16,384 name lookups/gets; 3.376 ms plugin CPU, 0.09 s process wall | Reaches direct full-name VPI lookup/get, but bypasses `uvm_hdl_read`, ECC, packed layout, and the full Flash population. Next fidelity step: wrap the same VPI calls in the real UVM DPI read path and compare packed-word reads with the four-byte reference. |
| 3. Sparse and joint Z3 enumeration | `/usr/bin/time -lp $VVP vvp_sparse_randomize.vvp`; `/usr/bin/time -lp $VVP vvp_joint_randomize.vvp`; C++ proxy commands below | Seeded sparse support/bin check; seeded tuple legality and all three legal tuples; C++ complete-set and uniqueness checks | VVP wall/draw bins; C++ checks, models, blockers and elapsed time | Invokes the real VVP enumerators, but constraint graphs/supports are synthetic, not extracted SPI/I2C/HMAC/TL/RV-DM inputs. No private helper-level counters. Next step: add helper counters, then lift one representative real constraint unchanged into a focused fixture. |
| 4. SRAM indexed VPI lookup | `/usr/bin/time -lp $VVP -M. -mhdl_lookup_bench sram_indexed_backdoor.vvp` | Plugin checks each indexed byte against initialized memory | 1 base + 16,384 indexed lookups/gets; 0.493 ms plugin CPU, <0.01 s process wall | Reaches `vpi_handle_by_index`, but bypasses `uvm_hdl_read`, SRAM path formatting, `find_name` scans, and fallback. Next step: use the real wrapper/path construction and count base-cache hits plus fallback scans. |
| 5. SVA/VPI callback dispatch | `/usr/bin/time -lp $VVP -M. -msva_vpi_dispatch sva_vpi_dispatch.vvp` | SV checks callback return/value behavior; C plugin checks arguments/scope and counts events | 1,000 each of `$ivl_sva_enabled`, `$ivl_assert_clock`, and value-change callbacks; 0 errors; 0.07 s process wall | Uses real helper entry points and VPI callbacks, but lacks OpenTitan assertion fanout and per-operation counters. Next step: profile real assertion-heavy test plus helper-level VPI operation counts. |
| 6. Object/context/liveness bookkeeping | `/usr/bin/time -lp $VVP class_context_liveness.vvp` | Checks owner/alias identity across automatic task/fork mutation and after dropping handles | 2,000 alias groups and checks; 0.01 s process wall | Semantic analogue; does not yet show that the full native alias-notification/context-map hot path or OpenTitan object-graph size is reached. Next step: add internal probe/fanout counters and replay a minimized real object graph. |
| 7. Four-state resolution | `/usr/bin/time -lp $VVP four_state_resolution.vvp` | Checks resolved outputs including X/Z results each cycle | 2,000 cycles, 8,000 X/Z checks; <0.01 s process wall | Reaches real four-state resolution, but fixture width/driver count do not match the profiled XBAR/Alert workloads and it has no `set_bit`/`reduce4` counters. Next step: match a profiled bus's width and driver fanout, then count conversions. |
| 8. Virtual-interface slot lookup | `/usr/bin/time -lp $VVP virtual_interface_slots.vvp` | Checks bound interface members and values through constructed holders | 64 constructions, 3 member reads, 64 value checks; <0.01 s process wall | Real VIF construction/access, but not KMAC's member set and without `resolve_slots_` scan/RTTI counters. Next step: copy the minimal KMAC interface shape and count scope scans and type checks. |
| 9. Standard distribution | `/usr/bin/time -lp $VVP standard_distribution.vvp` | Seeded support checks for every one of 2,000 `dist` samples | Histogram and 3.77 s process wall | Actual `std::randomize`/`dist`, but the distribution is synthetic. The histogram is not a frequency guarantee and there are no branch/solver/allocation counters. Next step: lift the exact Ibex distribution and compare weighted support exhaustively. |

In this table, `$VVP` is the executable assignment in Toolchain and commands.
The C++ proxy invocations are `./z3_sparse_bench spi 25`,
`./z3_sparse_bench i2c 25`, `./z3_sparse_bench hmac 25`,
`./z3_sparse_bench tl 25`, and `./z3_joint_bench 25`; their operation counts
and timings are listed above.

## Files

flash_aa_walk.cpp, flash_aa_walk.sv, flash_aa_semantics.sv, flash_walk_timer.c,
z3_sparse_bench.cpp, z3_joint_bench.cpp, vvp_sparse_randomize.sv,
vvp_joint_randomize.sv, hdl_lookup_bench.c, flash_backdoor.sv,
sram_indexed_backdoor.sv, four_state_resolution.sv,
class_context_liveness.sv, virtual_interface_slots.sv,
standard_distribution.sv, sva_vpi_dispatch.c, and sva_vpi_dispatch.sv.
