// IEEE 1800-2023 38.36.3: cbTchkViolation runs on each timing-check
// violation with obj set to the violated timing check (vpiTchk).
`timescale 1ns/1ns
module m(input clk, input d);
  reg n = 0;
  specify
    $setup(d, posedge clk, 5, n);
    $setuphold(posedge clk, d, 3, 3, n);
    $width(posedge clk, 4);
  endspecify
endmodule

module top;
  reg clk1 = 0, d1 = 0, clk2 = 0, d2 = 0;
  m u1(clk1, d1);
  m u2(clk2, d2);
  initial begin
    #10 d1 = 1;
    #2 clk1 = 1;   // t=12: u1 $setuphold(setup) and $setup
    #2 clk1 = 0;   // t=14: u1 $width
    #10 d2 = 1;
    #10 clk2 = 1;  // t=34: no setup violation
    #1 d2 = 0;     // t=35: u2 $setuphold(hold)
    #10 $finish(0);
  end
endmodule
