// A member that the modport does not list is not visible through a
// MODPORT-QUALIFIED virtual interface at all (IEEE 1800-2017 25.5). The
// modport is the view; anything outside it is not part of the handle's
// surface.
//
// Pins that the visibility check reaches the modport-qualified
// declaration form added in M5-6, not just interface ports.
interface bus_if;
  bit [7:0] data;
  bit [7:0] hidden;
  modport drv (output data);
endinterface

module main;
  bus_if sif();
  virtual bus_if.drv vdrv;

  initial begin
    vdrv = sif;
    vdrv.hidden = 8'd7;   // ILLEGAL: `hidden' is not in modport `drv'
  end
endmodule
