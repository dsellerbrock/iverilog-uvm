// Control for #3652: the same specify block inside a module is legal
// (IEEE 1800-2017/2023 30.3) and its path delay applies.
`timescale 1ns/1ns
module leaf(input wire a, output wire y);
  assign y = a;
  specify (a => y) = (1, 1); endspecify
endmodule
module top;
  reg a = 0;
  wire y;
  leaf u(a, y);
  initial begin
    #5 a = 1;
    #3 $display("y=%b at %0t", y, $time);
    if (y === 1'b1) $display("PASSED"); else $display("FAILED");
  end
endmodule
