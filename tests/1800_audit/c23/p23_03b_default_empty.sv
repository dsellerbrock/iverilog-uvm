module cnt(input [3:0] d = 4'h5, input [1:0] id);
 initial #1 $display("D%0d=%h", id, d);
endmodule
module top;
 cnt c1(.id(1));
 cnt c2(.id(2), .d());
 cnt c3(.id(3), .d(4'h0));
endmodule
