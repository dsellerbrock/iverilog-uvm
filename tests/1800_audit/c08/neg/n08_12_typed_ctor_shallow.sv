module top;
class B; int i; endclass B b1, b2; initial begin b1 = new; b2 = B::new b1; end
initial $display("NEG_NOT_REJECTED");
endmodule
