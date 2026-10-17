module top;
class Obj; endclass Obj a, b; initial begin a = new; b = new; if (a < b) $display("LT"); end
initial $display("NEG_NOT_REJECTED");
endmodule
