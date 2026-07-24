module top(input clk, d, en);
  specify $setup(edge[01,10] d, posedge clk &&& en, 3); $hold(posedge clk, d &&& (en==1'b1), 2); endspecify
endmodule
module tb; reg c=0,d=0,e=1; top t(c,d,e); initial begin #5 $display("PASS"); $finish(0); end endmodule
