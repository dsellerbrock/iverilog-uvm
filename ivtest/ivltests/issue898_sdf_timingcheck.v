// IEEE 1800-2017/2023 32.4.2, Table 32-2: SDF TIMINGCHECK entries annotate
// the limits of the matching timing checks. $tchk_dump (a VPI task) prints
// every limit of the cell after annotation, keyed by source line.
`timescale 1ns/1ns
module tc(input d, input clk, input rst, input en, input [1:0] b);
  reg n = 0;
  specify
    $setup(d, posedge clk, 1, n);                  // line 8
    $hold(posedge clk, d, 1, n);                   // line 9
    $setuphold(posedge clk &&& en, d, 1, 1, n);    // line 10
    $setuphold(negedge clk, d, 1, 1, n);           // line 11
    $recovery(posedge rst, posedge clk, 1, n);     // line 12
    $removal(posedge rst, posedge clk, 1, n);      // line 13
    $recrem(posedge rst, posedge clk, 1, 1, n);    // line 14
    $skew(posedge clk, posedge d, 1, n);           // line 15
    $timeskew(posedge clk, posedge d, 1, n);       // line 16
    $fullskew(posedge clk, posedge d, 1, 1, n);    // line 17
    $width(posedge clk, 1, 0, n);                  // line 18
    $period(posedge clk, 1, n);                    // line 19
    $nochange(posedge clk, d, 0, 0, n);            // line 20
    $setup(b[1], posedge clk, 1, n);               // line 21
  endspecify
endmodule

module top;
  reg d = 0, clk = 0, rst = 0, en = 1;
  reg [1:0] b = 0;
  tc u1(d, clk, rst, en, b);
  integer violations = 0;
  always @(u1.n) violations = violations + 1;
  // d rises 3 before the clock: only the conditioned $setuphold, whose
  // annotated setup limit is 14, reports; $setup's annotated 2 does not.
  initial begin
    $sdf_annotate("ivltests/issue898_sdf_timingcheck.sdf", top);
    $tchk_dump(top.u1);
    #7 d = 1;
    #3 clk = 1;
    #1 if (violations == 1) $display("PASSED");
    else $display("FAILED: %0d violations", violations);
    $finish;
  end
endmodule
