# OpenTitan hot-path reproducers

Bounded evidence probes for the paths in
[HOTPATHS.md](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md).
These are standalone fixtures, not production changes or full OpenTitan tests.
See the [optimization plan](../../docs/conformance/opentitan_hotpath_optimization.md)
for candidate changes, risks, and correctness work.

The full-map scan is capped at 1,024 numeric keys because a 262,144-key scan
would require over 68 billion backing-entry visits. Ordered alternatives walk
the full 262,148-key fixture.

## Toolchain and commands

Measurements used Apple ARM64 macOS 27.0:

| Tool | Version / fingerprint |
| --- | --- |
| Icarus engine | 13.0-devel, SHA-256 8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c |
| VVP runtime | 13.0-devel, SHA-256 2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570 |
| Z3 shared library | 5.1.0, SHA-256 45344d6a38b6f75304433c2458d6fa16bc4907d426c96e2bedf0a90603460422 |
| C++ compiler | Apple clang 21.0.0 |

The exact compiler wrapper and VVP paths were
/private/tmp/current-tools/bin/iverilog and /private/tmp/current-tools/bin/vvp;
the wrapper selects /private/tmp/current-ivl/ivl. VPI modules were built with
this checkout's iverilog-vpi and public headers, then loaded by the fingerprinted
VVP. For another build, edit the three tool paths below. Run from this directory:

    IVERILOG=/private/tmp/current-tools/bin/iverilog
    VVP=/private/tmp/current-tools/bin/vvp
    IVERILOG_VPI=../../local-install/bin/iverilog-vpi

    clang++ -O2 -std=c++17 flash_aa_walk.cpp -o flash_aa_walk
    clang++ -O2 -std=c++17 $(pkg-config --cflags z3) z3_sparse_bench.cpp $(pkg-config --libs z3) -Wl,-rpath,/opt/homebrew/opt/z3/lib -o z3_sparse_bench
    clang++ -O2 -std=c++17 $(pkg-config --cflags z3) z3_joint_bench.cpp $(pkg-config --libs z3) -Wl,-rpath,/opt/homebrew/opt/z3/lib -o z3_joint_bench
    $IVERILOG_VPI hdl_lookup_bench.c
    $IVERILOG_VPI sva_vpi_dispatch.c
    $IVERILOG -g2012 -s top -o flash_backdoor.vvp flash_backdoor.sv
    $IVERILOG -g2012 -s top -o sram_indexed_backdoor.vvp sram_indexed_backdoor.sv
    $IVERILOG -g2012 -s top -o four_state_resolution.vvp four_state_resolution.sv
    $IVERILOG -g2012 -s top -o class_context_liveness.vvp class_context_liveness.sv
    $IVERILOG -g2012 -s top -o virtual_interface_slots.vvp virtual_interface_slots.sv
    $IVERILOG -g2012 -s top -o standard_distribution.vvp standard_distribution.sv
    $IVERILOG -g2012 -s top -o sva_vpi_dispatch.vvp sva_vpi_dispatch.sv

    /usr/bin/time -lp ./flash_aa_walk 1024 262144
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

Each row is one run, not an average. Fixture timings do not predict whole-corpus
speedups.

### Flash associative-array successor walk

The C++ fixture mirrors compare_vec_keys_ ordering: signed-negative split, sign
extension, MSB-first 0 < 1 < X < Z, and width-prefixed raw-key tie-breaking.
It passed 231,200 comparator-pair checks over every 1–4 bit 0/1/X/Z key in
signed and unsigned modes, plus 680 current-algorithm successor checks. The
timed corpus has 262,144 18-bit numeric keys and four four-state keys.

| Structure / walk | Build | Full walk | Counts and correctness |
| --- | ---: | ---: | --- |
| Current full-map scan, 1,024 numeric + 4 four-state keys | 0.208 ms | 12.622 ms | 1,028 successors; 1,057,812 entries scanned; 1,585,690 comparator calls |
| Ordered std::set, full corpus, upper_bound per successor | 85.118 ms | 84.252 ms | 262,148 successors; 262,149 queries; 7,209,116 comparator calls |
| Same ordered set, iterator stream | included above | 1.034 ms | 262,148 successors |
| unordered_map plus ordered set, upper_bound per successor | 119.292 ms | 114.010 ms | 262,148 successors and hash lookups; exact key/value matches |
| Same hash/index pair, iterator stream | included above | 21.937 ms | 262,148 successors and hash lookups |

The full-size scan is disabled; no full-scan duration or speedup ratio is
extrapolated. upper_bound models an independent next query at every step. The
iterator result is a streaming best case; a generic SV next implementation
must also observe intervening array mutations.

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

These reproduce the solver-call shape, not VVP's private enumeration helpers,
candidate domains, or model extraction costs.

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
| Standard distribution randomization | 2,000 std::randomize calls; support checked | 2.03 s |
| SVA helper/VPI dispatch | 1,000 $ivl_sva_enabled, $ivl_assert_clock, and value-change callbacks; 0 errors | 0.07 s |

These fixtures hit the relevant VVP syntax/runtime path, but do not expose
private counters for set_bit/reduce4, context-map/liveness probes, VIF slot
resolution, or assertion-object fanout. The distribution histogram is one
seeded sample and does not assert a frequency guarantee.

## Files

flash_aa_walk.cpp, z3_sparse_bench.cpp, z3_joint_bench.cpp,
hdl_lookup_bench.c, flash_backdoor.sv, sram_indexed_backdoor.sv,
four_state_resolution.sv, class_context_liveness.sv,
virtual_interface_slots.sv, standard_distribution.sv, sva_vpi_dispatch.c,
and sva_vpi_dispatch.sv.
