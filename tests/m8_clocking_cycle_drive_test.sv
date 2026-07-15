// M8 increment 2c: cycle-delayed clocking drives `cb.out <= ##N v`
// (IEEE 1800-2017 14.16).
//
// Lowered to the intra-assignment repeat-event form
// `raw <= repeat (N) @(cb) v`: the value is captured when the
// statement executes and the drive lands at the Nth clocking event.
//
// Pinned behaviors:
//   1. `##1` after @(cb) lands at the NEXT edge, not immediately.
//   2. `##2` lands two edges out.
//   3. The driven VALUE is captured at statement time — later
//      changes to the RHS variable do not affect the in-flight
//      drive.
//   4. Overlapping in-flight drives to the same clockvar issued in
//      different cycles land independently at their own edges.

`timescale 1ns/1ns

module m8_clocking_cycle_drive_test;
  logic clk = 0;
  logic [7:0] dout = 8'h00;
  logic [7:0] src;
  int errors = 0;

  always #5 clk = ~clk;   // edges at 5, 15, 25, ...

  clocking cb @(posedge clk);
    output dout;
  endclocking

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // 1: ##1 after @(cb) lands at the next edge.
    @(cb);                    // t=5
    cb.dout <= ##1 8'hA1;
    #1;                       // t=6: not yet
    check(dout == 8'h00, "##1 does not land immediately");
    @(posedge clk);           // t=15: lands here
    #1;
    check(dout == 8'hA1, "##1 lands at the next edge");

    // 2 + 3: ##2 with value captured at statement time.
    @(cb);                    // t=25
    src = 8'hB7;
    cb.dout <= ##2 src;
    src = 8'hFF;              // must NOT affect the in-flight drive
    @(posedge clk);           // t=35 (1st edge after issue)
    #1;
    check(dout == 8'hA1, "##2 has not landed after one edge");
    @(posedge clk);           // t=45 (2nd edge): lands
    #1;
    check(dout == 8'hB7, "##2 lands at the second edge with captured value");

    // 4: overlapping in-flight drives land independently.
    @(cb);                    // t=55
    cb.dout <= ##2 8'hC2;     // lands at t=75
    @(cb);                    // t=65
    cb.dout <= ##2 8'hD2;     // lands at t=85
    @(posedge clk);           // t=75
    #1;
    check(dout == 8'hC2, "first overlapping drive lands at its edge");
    @(posedge clk);           // t=85
    #1;
    check(dout == 8'hD2, "second overlapping drive lands at its edge");

    if (errors == 0)
      $display("PASSED: all m8 cycle drive checks");
    else
      $display("FAILED: %0d m8 cycle drive checks", errors);
    $finish(0);
  end
endmodule
