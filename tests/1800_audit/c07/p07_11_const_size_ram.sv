module p07_11_const_size_ram;
  typedef logic [16:1] Word;
  Word Ram[0:9];
  localparam int SR = $size(Ram,2);
  initial $display("SR %0d", SR);
endmodule
