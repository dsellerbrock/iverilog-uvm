# Flash `read32()` backdoor batching

## Finding

OpenTitan's `mem_bkdr_util.read32()` composes four `read8()` calls. Each call
forms a VPI name and fetches the entire backing memory word. For Flash's
`EccHamming_76_68` layout, the utility exposes 8 data bytes per 76-bit word
(`byte_width == 8`, `bytes_per_word == 8`), so both aligned 32-bit halves come
from one raw read. The other 12 bits are ECC and are outside the selected data
slice.

The Flash-only candidate reads once and shifts the requested 32-bit lane. It
falls back to the base implementation if the width or layout differs; the base
implementation still owns alignment errors and all other cases. The patch
updates both the IP template and its generated Earlgrey copy:

[`flash_read32_once.patch`](../../docs/conformance/release_overlays/opentitan/flash_read32_once.patch)

The source preimage SHA-256 for both copies is
`6578e80e394c74f0b6c438ac5125eefdaaeaf60a3cd03318a5f69368929209eb`.
Apply it only to a disposable copy of the pinned OpenTitan source, with
`PATCH` pointing to the file in this repository:

```sh
patch --dry-run -p1 < "$PATCH"
patch -p1 < "$PATCH"
```

## Focused comparison

[`flash_read32_backdoor.sv`](flash_read32_backdoor.sv) exercises the real UVM
1.2 DPI `uvm_hdl_read` path over 76-bit array words. It checks both 32-bit
lanes, includes unknown data and ECC bits, and counts reads. Compile with the
same UVM 1.2 source used by the OpenTitan matrix:

```sh
IVERILOG=../../local-install/bin/iverilog
VVP=../../local-install/bin/vvp
UVM_HOME=/path/to/uvm-1.2/src

$IVERILOG -g2012 -gcommercial-unsafe -uvm --uvm-home="$UVM_HOME" \
  -s top -o flash_read32_backdoor.vvp flash_read32_backdoor.sv
$VVP -n flash_read32_backdoor.vvp +UVM_NO_RELNOTES +reference
$VVP -n flash_read32_backdoor.vvp +UVM_NO_RELNOTES
```

Five paired runs were measured while the Flash corpus test occupied one CPU
core. Both modes passed 32,768 reads with identical values and X behavior:

| Mode | UVM HDL reads | Median wall | Spread |
| --- | ---: | ---: | ---: |
| Four-read reference | 131,072 | 3.207 s | 0.310 s |
| One-read candidate | 32,768 | 1.218 s | 0.118 s |

The focused path is 62.03% faster at the median. The active full Flash run was
compiled before this source patch; an end-to-end patched Flash replay is still
required before promoting this optimization or updating the full-corpus result.
The reported spread is max-minus-min across five runs; despite roughly 10%
within-mode spread, the slowest one-read run was still much faster than the
fastest reference run.
