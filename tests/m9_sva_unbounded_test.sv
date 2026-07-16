// M9-2: unbounded final windows `##[m:$]` — weak eventually
// (IEEE 1800-2017 16.9.2). An obligation matures after m cycles and
// then waits; the awaited boolean satisfies every mature obligation;
// nothing fails in finite time. A synthesized final process reports
// obligations still pending at end of simulation (exercised by the
// second assertion; the message is informational).
`timescale 1ns/1ns
module m9_sva_unbounded_test;
  logic clk = 0, a = 0, b = 0, u1 = 0;
  int e = 0, p = 0;
  int errors = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk) a |-> ##[1:$] b) p++; else e++;
  assert property (@(posedge clk) u1 |-> ##[1:$] 1'b0) else e++;

  initial begin
    a = 1;
    @(posedge clk); #1; a = 0;      // t=5: obligation enters
    @(posedge clk); #1;             // t=15: waiting, no failure
    if (e != 0) begin errors++; $display("FAILED: spurious unbounded fail"); end
    b = 1;
    @(posedge clk); #1;             // t=25: satisfied
    b = 0;
    if (p == 0) begin errors++; $display("FAILED: satisfy pass-action missing"); end
    u1 = 1;
    @(posedge clk); #1; u1 = 0;     // left pending -> final report
    if (errors == 0) $display("PASSED: all m9 unbounded window checks");
    else $display("FAILED: %0d m9 unbounded checks", errors);
    $finish(0);
  end
endmodule
