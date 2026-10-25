module dut(input clk, input [1:0] d, output reg q); always @(posedge clk) q <= d[0]; endmodule
module top; reg clk=0; reg [1:0] d=0; wire q; dut u(clk,d,q); always #5 clk=~clk;
 initial begin $dumpports(u,"ports.vcd"); #10 d=1; #20 $dumpportsoff("ports.vcd"); #10 d=2; #10 $dumpportson("ports.vcd"); #10 d=3; #10 $dumpportsall("ports.vcd"); $dumpportsflush("ports.vcd"); #10 $finish; end endmodule
