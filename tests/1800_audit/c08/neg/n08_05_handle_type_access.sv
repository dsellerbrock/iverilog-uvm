module top;
class vector #(parameter width = 7, type T = int); endclass
vector #(3) v; initial begin v = new; $display((v.T)'(3.45)); end
initial $display("NEG_NOT_REJECTED");
endmodule
