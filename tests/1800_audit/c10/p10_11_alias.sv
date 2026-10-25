module p10_11_alias;
  wire [31:0] A, B;
  wire w1, w2;
  assign A = 32'h11223344;
  alias {A[7:0], A[15:8], A[23:16], A[31:24]} = B;
  alias w1 = w2;
  assign w2 = 1'b1;
  initial #1 $display("AL %h %b", B, w1);
endmodule
