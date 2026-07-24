module top(input clk, d, rst);
  specify $nochange(posedge clk, d, 0, 0); $timeskew(posedge clk, negedge rst, 5); $fullskew(posedge clk, negedge rst, 3, 4); endspecify
endmodule
module tb; reg c=0,d=0,r=1; top t(c,d,r); initial begin #5 $display("PASS"); $finish(0); end endmodule
