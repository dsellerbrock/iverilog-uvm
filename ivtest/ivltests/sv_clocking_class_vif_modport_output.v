// A modport-exported clocking block remains usable through a VIF stored in a
// class property, including the generated hidden output-buffer state.
`timescale 1ns/1ps

interface class_mp_clocking_output_if(input logic clk);
  logic raw;

  clocking driver_cb @(posedge clk);
    output raw;
  endclocking

  modport driver_mp(clocking driver_cb);
endinterface

class class_mp_clocking_output_holder;
  virtual class_mp_clocking_output_if.driver_mp vif;
endclass

module sv_clocking_class_vif_modport_output;
  logic clk = 1'b0;
  class_mp_clocking_output_if bus(clk);
  class_mp_clocking_output_holder holder;
  int failures = 0;

  always #5 clk = ~clk;

  initial begin
    holder = new;
    holder.vif = bus;
    bus.raw = 1'b0;

    // Buffered drive: generated obuf/pending properties are reached through
    // the class-held, modport-qualified VIF.
    #1 holder.vif.driver_cb.raw <= 1'b1;
    @(holder.vif.driver_cb);
    #1;
    if (bus.raw !== 1'b1) begin
      failures++;
      $display("FAILED buffered class-held modport drive: raw=%b", bus.raw);
    end

    // Current-event drive: the same path reads the generated buffer state.
    @(holder.vif.driver_cb);
    holder.vif.driver_cb.raw <= 1'b0;
    #1;
    if (bus.raw !== 1'b0) begin
      failures++;
      $display("FAILED current-event class-held modport drive: raw=%b",
               bus.raw);
    end

    if (failures != 0)
      $fatal(1, "%0d class-held modport output checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
