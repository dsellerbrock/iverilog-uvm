# Caliptra selected-input asynchronous synthesis

Date: 2026-08-24

Branch base after the required fresh-main transplant: `origin/main` at
`5907716805242cf4ec5554dd20372688af4d4d93`. The reduced red proof used the
immediately preceding main at `d248f8f6eaf8c91a23f52b3beb9b6fc53571aa37`;
the intervening merge changes copied SVA package actions and does not touch
this event/synthesis path.

The relevant IEEE 1800-2017 boundaries are implicit event controls and
combinational processes in 9.2 and 9.4, together with expression-connected
module input ports in clause 23. Caliptra RTL is an unmodified, read-only
compatibility workload; the implementation and permanent reducers are wholly
inside Icarus Verilog.

## Reduced failure

A child combinational process was rejected by synthesis when the child's
input formal was connected to a parent packed part-select:

```systemverilog
module leaf(input logic [4:0] i, output logic o);
  always @* o = ^i;
endmodule

module top(input logic [7:0] bus, output logic o);
  leaf u(.i(bus[4:0]), .o(o));
endmodule
```

The same failure occurred when the actual was a packed-struct field. The
baseline command

```sh
iverilog -g2012 -tnull -S -s top reducer.sv
```

exited zero but emitted `Process not synthesized.` for each selected-input
instance. A whole-net actual and an `always_comb` leaf were clean controls.

## Root cause and implementation

An implicit event that reads only part of a vector needs an exact probe. The
event elaborator represents that exact dependency with a private
`NetPartSelect`, and `NetEvent::nex_async_()` unwraps the probe back to the
source nexus plus base and width before comparing it with the process body's
input set.

The old code inferred that private provenance from topology alone: any
vector-to-part `NetPartSelect` attached to the probe nexus was treated as the
compiler-generated sensitivity carrier. A normal child input connected to a
parent part-select has the same topology after module-port linking. The event
side was therefore rewritten to the parent source, while
`statement_->nex_input()` correctly remained on the child formal. The
asynchronous-process classifier saw unequal nexus sets and synthesis skipped a
valid combinational process.

The private sensitivity select is now marked explicitly when it is created.
`NetEvent::nex_async_()` unwraps only a select carrying that marker. Ordinary
module-port part-selects remain ordinary connections, so the event and body
input sets agree. The marker is local netlist provenance; it does not change a
source select's simulation value, port direction, or target ABI.

The opposite case is pinned separately: `always @* parity = ^in[4:0]` still
creates and unwraps the marked exact probe. This prevents a future change from
fixing selected ports by disabling precise implicit sensitivity altogether.
Whole-net `always @*` and selected-port `always_comb` controls are also
value-checked.

## Validation

- Focused legacy synthesis: 2/2 passed.
- Focused JSON/VVP, ordinary plus `-S`: 4/4 passed with split-stream gold.
- Slang 1800-2017 accepted both the selected-port reducer and the precise,
  whole-net, and `always_comb` controls with zero errors or warnings.
- Full JSON/VVP sweep: 922/922 passed after installing the configured optional
  FPGA target used by two existing negative tests.
- Full SystemVerilog legacy sweep: 1,853/1,853 passed after installing the
  worktree's pinned UVM dependency.
- Full synthesis-list differential: corrected compiler 133/151 versus
  baseline 132/151. The only changed result is the new positive reducer; all
  18 pre-existing list failures are identical.
- The baseline compiler fails the selected-port synthesis reducer while the
  precise-select control passes.
- Unmodified Caliptra `sha512_masked_core` synthesis no longer reports the
  `sha512_masked_w_mem.sv:180` skipped process.
- Unmodified Caliptra `soc_ifc_top` synthesis no longer reports the ten
  repeated `axi_addr.v` skipped-process warnings (five blocks in two
  instances). Four separate `caliptra_prim_sparse_fsm_flop.sv:65` warnings
  remain unchanged.

The Caliptra checks used its required environment:

```sh
CALIPTRA_ROOT=<checkout>
CALIPTRA_PRIM_ROOT=<checkout>/src/caliptra_prim_generic
CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
```

All compiler and simulator invocations used the native Apple Silicon build
from this worktree through `evidence/arm64-tooling/resource-runner`, retaining
the 45-second per-process CPU guard and imposing no RSS ceiling.
