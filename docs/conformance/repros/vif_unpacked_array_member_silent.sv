// M1C-4 (FIXED) -- minimization trail. An UNPACKED ARRAY member of an
// interface, reached through a VIRTUAL interface, used to read `x' and
// silently drop writes:
//
//   vif     arr[const]  = x  (want 82)
//   after vif write const: direct arr[2] = 82 (want 90)
//
// No diagnostic, exit 0. Direct access through the instance was correct,
// and so was every scalar member through the same handle.
//
// ROOT CAUSE: the member got no slot at all. A virtual-interface handle
// resolves each member of the interface class type to a slot backed by
// the instance's VPI handle, and the resolver skipped anything that was
// not a signal / real / string / base variable. An unpacked array's
// handle is a `__vpiArray', so it fell through -- reads returned an empty
// value and writes returned early.
//
// FIXED by a SLOT_ARRAY kind whose element index selects the word.
// Reals and strings went the same way: their accessors discarded the
// index outright (`(void)idx'). Regression:
// ivtest/ivltests/sv_vif_array_member.v.
//
// This file now prints the wanted value on every line.

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
