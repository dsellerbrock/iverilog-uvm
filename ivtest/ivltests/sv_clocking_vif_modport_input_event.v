// A modport-exported clocking block remains usable as both a VIF event and a
// sampled input namespace through a modport-qualified virtual interface.
`timescale 1ns/1ps

interface mp_clocking_input_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

module sv_clocking_vif_modport_input_event;
  logic clk = 1'b0;
  mp_clocking_input_if bus(clk);
  virtual mp_clocking_input_if.monitor_mp vif;
  int failures = 0;

  always #5 clk = ~clk;

  initial begin
    vif = bus;
    bus.raw = 1'b1;

    @(vif.monitor_cb);
    if (vif.monitor_cb.raw !== 1'b1) begin
      failures++;
      $display("FAILED first modport clocking sample: sample=%b",
               vif.monitor_cb.raw);
    end

    // The clockvar retains the sampled value until the next event.
    #1 bus.raw = 1'b0;
    if (vif.monitor_cb.raw !== 1'b1) begin
      failures++;
      $display("FAILED retained modport clocking sample: sample=%b",
               vif.monitor_cb.raw);
    end

    @(vif.monitor_cb);
    if (vif.monitor_cb.raw !== 1'b0) begin
      failures++;
      $display("FAILED second modport clocking sample: sample=%b",
               vif.monitor_cb.raw);
    end

    if (failures != 0)
      $fatal(1, "%0d modport clocking-input/event checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
