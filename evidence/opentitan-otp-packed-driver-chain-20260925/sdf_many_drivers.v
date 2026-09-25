`timescale 1ns/1ps
module tb;
  reg in;
  wire out;
  top dut(out, in);
  initial begin
    $monitor("%.3f %b", $realtime, out);
    $sdf_annotate("sdf_many_drivers.sdf");
    #1 in=0;
    #1 in=1;
    #1 in=0;
    #1 $finish;
  end
endmodule
module top(output wire out, input wire in);
  wire [5:0] v;
  assign v[0]=in;
  buff i1(.Y(v[1]), .A(v[0]));
  buff i2(.Y(v[2]), .A(v[1]));
  buff i3(.Y(v[3]), .A(v[2]));
  buff i4(.Y(v[4]), .A(v[3]));
  buff i5(.Y(v[5]), .A(v[4]));
  assign out=v[5];
endmodule
`celldefine
module buff(output wire Y, input wire A);
  buf (Y, A);
  specify (A => Y)=0; endspecify
endmodule
`endcelldefine
