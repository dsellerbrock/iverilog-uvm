# Caliptra selected-input asynchronous synthesis

Date: 2026-08-24

The original fix was based on `origin/main` at
`5907716805242cf4ec5554dd20372688af4d4d93`; its post-merge review refinement
is based on `873ee7b4cdf50f50b805148eae9a519612a576ee`. The reduced red proof used
the immediately preceding main at
`d248f8f6eaf8c91a23f52b3beb9b6fc53571aa37`.

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

An `always_comb` or `always_latch` event that reads only part of a vector can
use a private `NetPartSelect` to retain exact simulation sensitivity.
Separately, `NetEvent::nex_async_()` builds the dependency set used by the
synthesis classifier. The old helper inferred private provenance from topology
alone: any vector-to-part `NetPartSelect` attached to a probe nexus was treated
as a compiler-generated sensitivity carrier and rewritten to its source nexus
plus base and width.

A normal child input connected to a parent part-select has the same topology
after module-port linking. Its event side was therefore rewritten to the
parent source, while
`statement_->nex_input()` correctly remained on the child formal. The
asynchronous-process classifier saw unequal nexus sets and synthesis skipped a
valid combinational process.

`NetEvent::nex_async_()` now keeps each event probe nexus as elaborated. It no
longer searches neighboring `NetPartSelect` nodes and guesses that one is a
private sensitivity carrier: a normal selected module-port connection has the
same topology after port linking, so that inference cannot be sound. The event
and body input sets consequently stay in the child namespace and agree.

`always_comb` and `always_latch` exact selected probes do not need this
synthesis-time rewrite. Their compiler-generated waits carry a time-zero
trigger, and asynchronous classification returns after confirming that every
probe is `ANYEDGE`; the exact selected event used by simulation remains
unchanged. Existing `sv_always_comb_precise_select_sens` observes that an
unselected bit does not wake the process. The new
`synth_precise_select_async_control` checks that a selected `always_comb` read,
a whole-net `always @*` read, and a selected-port `always_comb` process all
remain synthesizable and value-correct.

## Validation

- The post-merge refinement reran the focused legacy 2/2, JSON/VVP 4/4,
  `sv_always_comb_precise_select_sens`, and the Slang 1800-2017 control; all
  passed with zero new diagnostics.
- Focused legacy synthesis: 2/2 passed.
- Focused JSON/VVP, ordinary plus `-S`: 4/4 passed with split-stream gold.
- Slang 1800-2017 accepted both the selected-port reducer and the selected-read,
  whole-net, and `always_comb` controls with zero errors or warnings.
- Full JSON/VVP sweep: 922/922 passed after installing the configured optional
  FPGA target used by two existing negative tests.
- Full SystemVerilog legacy sweep: 1,853/1,853 passed after installing the
  worktree's pinned UVM dependency.
- Full synthesis-list differential: corrected compiler 133/151 versus
  baseline 132/151. The only changed result is the new positive reducer; all
  18 pre-existing list failures are identical.
- The baseline compiler fails the selected-port synthesis reducer while the
  selected-read and whole-net controls pass.
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
