`timescale 1ns/1ps

interface drive_bus(input logic clk);
  logic [3:0] raw = 0;
  logic [3:0] delayed = 0;
  logic sample = 1;
  clocking cb @(posedge clk);
    input sample;
    output raw;
    output #2 delayed;
  endclocking
endinterface

program automatic reactive_driver;
  virtual drive_bus vif;
  bit barrier;

  initial begin
    vif = issue3879_clocking_output_renba.bus;
    @(vif.cb);
    if (vif.raw[2:0] !== 0)
      $error("Reactive saw zero-skew output early: %b", vif.raw);
    vif.cb.raw[1:0] <= 2'b10;

    @(issue3879_clocking_output_renba.next_pass);
    if (vif.raw !== 4'b1110)
      $error("first Re-NBA published the wrong value: %b", vif.raw);
    vif.cb.raw[0] <= 1;
    // Replace a bit of the earlier snapshot, which has yet to mature.
    vif.cb.delayed[0] <= 0;
    barrier <= 1;
    @(barrier);
    if (vif.raw !== 4'b1111)
      $error("Reactive kick missed its Re-NBA pass: %b", vif.raw);

    #2;
    if ($time != 7 || vif.delayed !== 4'b1000)
      $error("Reactive did not see the old value at skew delivery: %b", vif.delayed);
    #2;
  end
endprogram

module issue3879_clocking_output_renba;
  logic clk = 0;
  drive_bus bus(clk);
  reactive_driver driver();
  event next_pass;

  initial begin
    bus.cb.raw[2:0] <= 3'b101;
    bus.cb.delayed[2:0] <= 3'b101;
    #5;
    bus.sample = 0;
    clk = 1;
    #1;
    if (bus.raw !== 4'b1111 || bus.delayed !== 0)
      $error("wrong values after the clock edge: %b %b", bus.raw, bus.delayed);
    // A raw write after capture must survive the delayed update.
    bus.delayed[3] = 1;
    #2;
    if (bus.delayed !== 4'b1100)
      $fatal(1, "wrong delayed output: %b", bus.delayed);
    $display("PASSED");
    $finish(0);
  end

  initial begin
    @(bus.cb);
    if (bus.cb.sample !== 1 || bus.raw !== 0)
      $error("module @(cb) did not see its sample and the old output");
    bus.raw[3] = 1;
  end

  initial begin
    #1;
    @(bus.raw[2:0]);
    -> next_pass;
  end

  initial begin
    #1;
    @(posedge (bus.raw[2] ^ bus.raw[1]));
    $fatal(1, "zero-skew drive exposed an intermediate value");
  end

  initial begin
    #1;
    @(posedge bus.delayed[0]);
    $fatal(1, "superseded delayed value was published");
  end
endmodule
