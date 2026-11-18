`timescale 1ns/1ps

interface forward_if(input logic clk);
  logic data;
  modport monitor(clocking cb);

  clocking cb @(posedge clk);
    input data;
  endclocking
endinterface

module sv_modport_clocking_forward;
  logic clk = 0;
  forward_if bus(clk);
  virtual forward_if.monitor vif;
  bit passed;

  initial begin
    #5 clk = 1;
    #5 clk = 0;
    #5 clk = 1;
    #5 if (!passed) $fatal(1, "Timed out waiting for the modport clocking events");
  end

  initial begin
    vif = bus;
    bus.data = 1;
    @(vif.cb);
    if ($time != 5 || vif.cb.data !== 1'b1)
      $fatal(1, "Wrong time or sampled data for the first clocking event");

    #1 bus.data = 0;
    if (vif.cb.data !== 1'b1)
      $fatal(1, "Clocking input did not retain the first sample");

    @(vif.cb);
    if ($time != 15 || vif.cb.data !== 1'b0)
      $fatal(1, "Wrong time or sampled data for the second clocking event");
    passed = 1;
    $display("PASSED");
  end
endmodule
