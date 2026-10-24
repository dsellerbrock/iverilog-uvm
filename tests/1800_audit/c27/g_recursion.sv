module chain #(parameter N=3)(output [N:0] o);
 if (N>0) begin:s wire [N-1:0] sub; chain #(N-1) c(sub); assign o = {sub,1'b1}; end else assign o = 1'b1;
endmodule
module top; wire [3:0] r; chain #(3) c(r); initial #1 $display("G6 %b", r); endmodule
