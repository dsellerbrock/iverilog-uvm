// A positive numeric input skew uses the delayed shadow / phase-2 sampler.
// Both static and VIF clocking-event waiters must resume only after the
// historical value has been copied into the clockvar.
`timescale 1ns/1ps

interface numeric_delay_skew_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    input #2 raw;
  endclocking
endinterface

module sv_clocking_vif_numeric_input_skew_delay_order;
  logic clk = 1'b0;
  numeric_delay_skew_if bus(clk);
  virtual numeric_delay_skew_if vif;
  bit static_seen = 1'b0;
  bit vif_seen = 1'b0;

  always #5 clk = ~clk;

  initial begin
    bus.raw = 1'b0;
    #1 bus.raw = 1'b1;
    #3 bus.raw = 1'b0;
  end

  initial begin
    vif = bus;
    @(vif.cb);
    if ($time != 5 || vif.cb.raw !== 1'b1)
      $fatal(1, "VIF #2 sample woke early or stale: time=%0t sample=%b",
             $time, vif.cb.raw);
    vif_seen = 1'b1;
  end

  initial begin
    @(bus.cb);
    if ($time != 5 || bus.cb.raw !== 1'b1)
      $fatal(1, "static #2 sample woke early or stale: time=%0t sample=%b",
             $time, bus.cb.raw);
    static_seen = 1'b1;
  end

  initial begin
    #6;
    if (!static_seen || !vif_seen)
      $fatal(1, "numeric #2 waiters did not both resume");
    $display("PASSED");
    $finish;
  end
endmodule
