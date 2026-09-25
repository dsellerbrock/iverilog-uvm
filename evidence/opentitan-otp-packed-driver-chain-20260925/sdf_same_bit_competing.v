`timescale 1ns/1ps
module tb;
  reg in, contender;
  wire out;
  top dut(out, in, contender);

  initial begin
    contender = 1'bz;
    $sdf_annotate("sdf_same_bit_competing.sdf");
    #1 in = 0;
    #1 in = 1;
    #1 contender = 0;
    #1 contender = 1;
    #1 $display("COMPLETED");
    #1 $finish;
  end
endmodule

module top(output wire out, input wire in, contender);
  wire [2:0] intv;
  assign intv[0] = in;
  buff i1(.Y(intv[1]), .A(intv[0]));
  assign intv[1] = contender;
  buff i2(.Y(intv[2]), .A(intv[1]));
  assign out = intv[2];
endmodule

`celldefine
module buff(output wire Y, input wire A);
  buf (Y, A);
  specify (A => Y) = 0; endspecify
endmodule
`endcelldefine
