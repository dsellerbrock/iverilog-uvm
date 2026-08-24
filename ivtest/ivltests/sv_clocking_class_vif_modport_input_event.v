// A class-held, modport-qualified VIF exposes its exported clocking event and
// sampled input namespace, while retaining clockvar sampling semantics.
`timescale 1ns/1ps

interface class_mp_clocking_input_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

class class_mp_clocking_input_holder;
  virtual class_mp_clocking_input_if.monitor_mp vif;
endclass

module sv_clocking_class_vif_modport_input_event;
  logic clk = 1'b0;
  class_mp_clocking_input_if bus(clk);
  class_mp_clocking_input_holder holder;
  int failures = 0;

  always #5 clk = ~clk;

  initial begin
    holder = new;
    holder.vif = bus;
    bus.raw = 1'b1;

    @(holder.vif.monitor_cb);
    if (holder.vif.monitor_cb.raw !== 1'b1) begin
      failures++;
      $display("FAILED first class-held modport sample: sample=%b",
               holder.vif.monitor_cb.raw);
    end

    #1 bus.raw = 1'b0;
    if (holder.vif.monitor_cb.raw !== 1'b1) begin
      failures++;
      $display("FAILED retained class-held modport sample: sample=%b",
               holder.vif.monitor_cb.raw);
    end

    @(holder.vif.monitor_cb);
    if (holder.vif.monitor_cb.raw !== 1'b0) begin
      failures++;
      $display("FAILED second class-held modport sample: sample=%b",
               holder.vif.monitor_cb.raw);
    end

    if (failures != 0)
      $fatal(1, "%0d class-held modport input/event checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
