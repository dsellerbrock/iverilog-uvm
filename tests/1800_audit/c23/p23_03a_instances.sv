parameter logic [7:0] My_DataIn = 8'hFF;
module alu(output reg [7:0] alu_out, output reg zero, input [7:0] ain, bin, input [2:0] opcode); always_comb begin alu_out=ain+bin; zero=(alu_out==0); end endmodule
module accum(output reg [7:0] dataout, input [7:0] datain = My_DataIn, input clk, rst_n = 1'b1); always_comb dataout = rst_n ? datain : 8'h00; endmodule
module xtend(output reg [7:0] dout, input din, input clk, rst = 1'b0); always_comb dout = rst ? 8'h00 : {8{din}}; endmodule
module alu_accum1(output [15:0] dataout, input [7:0] ain, bin, input [2:0] opcode, input clk, rst_n, rst);
 wire [7:0] alu_out;
 alu alu(alu_out, , ain, bin, opcode); accum accum(dataout[7:0], alu_out, clk, rst_n); xtend xtend(dataout[15:8], alu_out[7], clk);
endmodule
module alu_accum2(output [15:0] dataout, input [7:0] ain, bin, input [2:0] opcode, input clk, rst_n, rst);
 wire [7:0] alu_out;
 alu alu(.alu_out(alu_out), .zero(), .ain(ain), .bin(bin), .opcode(opcode));
 accum accum(.dataout(dataout[7:0]), .datain(alu_out), .clk(clk));
 xtend xtend(.dout(dataout[15:8]), .din(alu_out[7]), .clk(clk), .rst());
endmodule
module alu_accum3(output [15:0] dataout, input [7:0] ain, bin, input [2:0] opcode, input clk, rst_n);
 wire [7:0] alu_out;
 alu alu(.alu_out, .zero(), .ain, .bin, .opcode); accum accum(.dataout(dataout[7:0]), .datain(alu_out), .clk, .rst_n());
 xtend xtend(.dout(dataout[15:8]), .din(alu_out[7]), .clk, .rst(1'b0));
endmodule
module alu_accum4(output [15:0] dataout, input [7:0] ain, bin, input [2:0] opcode, input clk);
 wire [7:0] alu_out;
 alu alu(.*, .zero()); accum accum(.*, .dataout(dataout[7:0]), .datain(alu_out)); xtend xtend(.*, .dout(dataout[15:8]), .din(alu_out[7]));
endmodule
module alu_accum5(output [15:0] dataout, input [7:0] ain, bin, input [2:0] opcode, input clk, rst_n);
 wire [7:0] alu_out;
 alu alu(.ain(ain), .bin(bin), .alu_out, .zero(), .opcode); accum accum(dataout[7:0], alu_out, clk, rst_n); xtend xtend(.dout(dataout[15:8]), .*, .din(alu_out[7]));
endmodule
module cnt1(output reg [3:0] n, input [3:0] d = 4'h5); initial begin #1 $display("CNT %0d", d); end endmodule
module top;
 reg clk=0; reg rst_n=1, rst=0; reg [7:0] ain=8'd3, bin=8'd4; reg [2:0] op=0; wire [15:0] d1,d2,d3,d4,d5;
 alu_accum1 a1(d1,ain,bin,op,clk,rst_n,rst); alu_accum2 a2(d2,ain,bin,op,clk,rst_n,rst); alu_accum3 a3(d3,ain,bin,op,clk,rst_n);
 alu_accum4 a4(d4,ain,bin,op,clk); alu_accum5 a5(d5,ain,bin,op,clk,rst_n);
 wire [3:0] n1,n2,n3; cnt1 c1(n1), c2(.n(n2), .d()), c3(.n(n3));
 wire [1:0] arr_o [3:0]; wire [1:0] q;
 initial begin #1 $display("D %h %h %h %h %h", d1,d2,d3,d4,d5); $display("ROOT %0d", $root.top.ain); end
endmodule
