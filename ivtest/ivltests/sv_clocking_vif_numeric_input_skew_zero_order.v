// A virtual-interface clocking event must not wake until the numeric #0
// input-skew sample is stored. The static and VIF paths name the same
// clocking event and must expose the same post-NBA sample.
`timescale 1ns/1ps

interface numeric_zero_skew_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    input #0 raw;
  endclocking
endinterface

module sv_clocking_vif_numeric_input_skew_zero_order;
  logic clk = 1'b0;
  numeric_zero_skew_if bus(clk);
  virtual numeric_zero_skew_if vif;
  bit static_seen = 1'b0;
  bit vif_seen = 1'b0;

  always #5 clk = ~clk;
  always @(posedge clk) bus.raw <= 1'b1;

  initial begin
    bus.raw = 1'b0;
    vif = bus;
    @(vif.cb);
    if ($time != 5 || vif.cb.raw !== 1'b1)
      $fatal(1, "VIF #0 sample woke early or stale: time=%0t sample=%b",
             $time, vif.cb.raw);
    vif_seen = 1'b1;
  end

  initial begin
    @(bus.cb);
    if ($time != 5 || bus.cb.raw !== 1'b1)
      $fatal(1, "static #0 sample woke early or stale: time=%0t sample=%b",
             $time, bus.cb.raw);
    static_seen = 1'b1;
  end

  initial begin
    #6;
    if (!static_seen || !vif_seen)
      $fatal(1, "numeric #0 waiters did not both resume");
    $display("PASSED");
    $finish;
  end
endmodule
