# UVM DPI HDL read reproducer

`uvm_hdl_read_backdoor.sv` exercises UVM 1.2's actual `uvm_hdl_read` DPI path
against 256 byte-wide array elements. It reads every element eight times,
checks each value, changes one element, and confirms the next read observes
the update. A successful run prints:

```text
PASS uvm_hdl_read_backdoor calls=2049
```

Compile and run with the same UVM 1.2 source tree used by the OpenTitan matrix:

```sh
IVERILOG=../../local-install/bin/iverilog
VVP=../../local-install/bin/vvp
UVM_HOME=/path/to/uvm-1.2/src

$IVERILOG -g2012 -gcommercial-unsafe -uvm --uvm-home="$UVM_HOME" \
  -s top -o uvm_hdl_read_backdoor.vvp uvm_hdl_read_backdoor.sv
/usr/bin/time -lp $VVP -n uvm_hdl_read_backdoor.vvp
```

The wrapper resolves each full path through `uvm_ivl_hdl_lookup_sel`, which
calls `vpi_handle_by_name`, then gets the current signal value. In the 900 s
Flash profile, the VPI lookup stack accounted for about 6.8% of main-thread
samples; see the [sample](../../evidence/opentitan-census-20261002/candidate-runtime-after-scalar-uniform-20261006/flash-900s.sample.txt).

A bounded VPI-handle cache was tested with this fixture scaled to 32,769 real
UVM reads. Across seven paired runs under the active Flash workload, median
wall time was 1.0367 s without the cache and 1.0278 s with it, a 0.86% change.
That gain was too small to justify retaining the cache implementation; the
fixture remains as the minimal probe for future lookup changes.
