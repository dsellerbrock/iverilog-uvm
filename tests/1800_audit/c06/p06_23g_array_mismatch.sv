module p06_23g;
  typedef logic [1:0][3:0] NIBBLES; typedef logic [7:0] MY_BYTE;
  initial $display("MATCH=%0d", type(NIBBLES)==type(MY_BYTE));
endmodule
