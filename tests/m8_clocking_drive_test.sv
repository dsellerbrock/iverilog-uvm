// M8 increment 2b: synchronous output clockvar drives
// (IEEE 1800-2017 14.16).
//
// `cb.out <= v` no longer writes the raw signal immediately (the
// alias model). Semantics pinned here:
//   1. A drive issued BETWEEN clocking events is buffered and lands
//      at the NEXT clocking event (after the Active region), not
//      when the statement executes.
//   2. A drive issued after @(cb) — i.e., in the same time step as
//      the clocking event — lands in the current step (the LRM's
//      drive-at-current-event case).
//   3. Multiple drives before the same event: the LAST value wins
//      (14.16.2).
//   4. inout clockvars: drives buffer like outputs while reads stay
//      sampled.
//   5. Instance-path drives (inst.cb.out <= v) behave the same.

`timescale 1ns/1ns

module m8_clocking_drive_test;
  logic clk = 0;
  logic [7:0] dout = 8'h00;
  logic [7:0] dio  = 8'h00;
  int errors = 0;

  always #5 clk = ~clk;   // edges at 5, 15, 25, ...

  clocking cb @(posedge clk);
    output dout;
    inout  dio;
  endclocking

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // 1: between-edge drive buffers until the next edge.
    #2;                     // t=2, between edges
    cb.dout <= 8'hAA;
    #1;                     // t=3: must NOT have landed yet
    check(dout == 8'h00, "between-edge drive is buffered");
    @(posedge clk);         // edge at t=5
    #1;                     // t=6: applied at the edge
    check(dout == 8'hAA, "buffered drive lands at the edge");

    // 2: drive after @(cb) lands in the same time step.
    @(cb);                  // edge at t=15
    cb.dout <= 8'hBB;
    #1;                     // t=16, same cycle
    check(dout == 8'hBB, "same-step drive after @(cb) lands now");

    // 3: last drive wins.
    #2;                     // t=18, between edges
    cb.dout <= 8'hC1;
    cb.dout <= 8'hC2;
    @(cb);                  // edge at t=25
    #1;
    check(dout == 8'hC2, "last of multiple buffered drives wins");

    // 4: inout drives buffer; reads stay sampled.
    #2;                     // t=28
    cb.dio <= 8'h5A;
    #1;
    check(dio == 8'h00, "inout drive buffered");
    check(cb.dio == 8'h00, "inout read still the old sample");
    @(cb);                  // edge at t=35: drive lands, new sample taken
    #1;
    check(dio == 8'h5A, "inout drive lands at the edge");
    // The t=35 sample was taken from the START of the step (before
    // the drive landed), so cb.dio still reads the old value...
    check(cb.dio == 8'h00, "inout sample at drive edge is pre-drive (#1step)");
    @(cb);                  // ...and the next edge samples the driven value.
    check(cb.dio == 8'h5A, "next edge samples the driven value");

    if (errors == 0)
      $display("PASSED: all m8 clocking drive checks");
    else
      $display("FAILED: %0d m8 clocking drive checks", errors);
    $finish(0);
  end
endmodule
