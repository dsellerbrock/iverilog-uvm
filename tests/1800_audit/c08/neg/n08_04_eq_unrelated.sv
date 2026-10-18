module top;
class A; endclass class Bq; endclass A a; Bq b; initial begin a = new; b = new; if (a == b) $display("EQ"); end
initial $display("NEG_NOT_REJECTED");
endmodule
