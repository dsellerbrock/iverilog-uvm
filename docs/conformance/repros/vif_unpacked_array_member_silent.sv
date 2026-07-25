// M1C-4 (OPEN, rule gate 1 — SILENT): an UNPACKED ARRAY member of an
// interface, reached through a VIRTUAL interface, reads `x' and writes to
// it are silently dropped.
//
//   iverilog -g2012 -o a.vvp <this file> && vvp a.vvp
//
//   direct  arr[2]      = 82 (want 82)     <-- direct access is correct
//   vif     arr[const]  = x  (want 82)
//   vif     arr[var]    = x  (want 82)
//   vif     data        = 7  (want 7)      <-- scalar members are correct
//   after vif write const: direct arr[2] = 82 (want 90)
//   after vif write var  : direct arr[2] = 82 (want 91)
//
// No diagnostic, exit 0. The write is the dangerous half: a testbench
// driving an interface array through a virtual interface -- the ordinary
// UVM driver shape -- silently drives nothing.
//
// What is known:
//
//   * Scalar interface members through the same virtual interface are
//     correct, as are all direct (non-virtual) accesses. The defect is
//     specific to an unpacked-array member reached through the handle.
//   * The lowering already emits an INDEXED property access --
//     `%prop/v/i 0, 4' to read and `%store/prop/v/i 0, 4, 8' to write --
//     so the index reaches the runtime; what it indexes is the question.
//   * An interface is mirrored into a netclass_t in elab_type.cc
//     (`iface_type->set_property(cur->first, ..., prop_type)` over
//     `mod->wires`), one property per member, and the property's array
//     storage comes from the elaborated member TYPE. The first thing to
//     check is whether `elaborate_sig_type` returns the unpacked-array
//     type here or just the element type -- a single-slot property would
//     explain both the `x' read and the dropped write.
//   * This is the same shape as M1C-3, which is fixed: an indexed access
//     whose index has nowhere to go because the property holds one slot.
//     M1C-3 covered containers in CLASS properties; this is the interface
//     mirror.
//
// Found by the M1C Cartesian access probe (container x element kind x
// operation x index), batch 2, which also confirmed that every other
// interface shape in that batch -- scalar read/write/compound through
// both a direct and a virtual interface, interface task call through a
// virtual interface, bit and part selects on a scalar member -- is
// correct.
interface bus_if;
  bit [7:0] data;
  bit [7:0] arr[4];
endinterface

module main;
  bus_if sif();
  virtual bus_if vif;
  int k = 2;

  initial begin
    sif.data = 8'd7;
    for (int i = 0; i < 4; i++) sif.arr[i] = i + 80;
    vif = sif;

    $display("direct  arr[2]      = %0d (want 82)", sif.arr[2]);
    $display("vif     arr[const]  = %0d (want 82)", vif.arr[2]);
    $display("vif     arr[var]    = %0d (want 82)", vif.arr[k]);
    $display("vif     data        = %0d (want 7)",  vif.data);

    vif.arr[2] = 8'd90;
    $display("after vif write const: direct arr[2] = %0d (want 90)", sif.arr[2]);
    vif.arr[k] = 8'd91;
    $display("after vif write var  : direct arr[2] = %0d (want 91)", sif.arr[2]);
  end
endmodule
