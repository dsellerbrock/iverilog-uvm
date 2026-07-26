// A write through a MODPORT-QUALIFIED virtual interface to a member the
// modport declares as `input' is illegal (IEEE 1800-2017 25.5): the
// modport view is what the handle may do, and an input may only be read.
//
// `virtual bus_if.mon' became writable at all only when the
// modport-qualified type stopped being a syntax error (M5-6), so this
// pins that the direction check reaches the new declaration form -- the
// same check the interface PORT path already applied.
//
// The positive half (reading an input, writing an output, and calling an
// interface task) lives in ivtest sv_vif_modport_qualified.
interface bus_if;
  bit [7:0] data;
  bit [7:0] arr[4];
  modport mon (input data, input arr);
endinterface

module main;
  bus_if sif();
  virtual bus_if.mon vmon;

  initial begin
    vmon = sif;
    vmon.data = 8'd5;   // ILLEGAL: `data' is an input in modport `mon'
  end
endmodule
