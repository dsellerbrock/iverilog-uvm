`timescale 1ns/1ps
module tb;
  reg in;
  wire out, wrong;
  top dut(out, wrong, in);
  initial begin
    $sdf_annotate("sdf_wrong_bit.sdf");
    #1 in = 1'b0;
    #1 in = 1'b1;
    #1 $finish;
  end
endmodule
module top(output wire out, wrong, input wire in);
  wire [2:0] intv;
  assign intv[0] = in;
  buff i0 (.Y(wrong), .A(intv[0]));
  buff i1 (.Y(intv[1]), .A(intv[0]));
  buff i2 (.Y(intv[2]), .A(intv[1]));
  assign out = intv[2];
endmodule
`celldefine
module buff(output wire Y, input wire A);
  buf (Y, A);
  specify (A => Y) = 0; endspecify
endmodule
`endcelldefine
