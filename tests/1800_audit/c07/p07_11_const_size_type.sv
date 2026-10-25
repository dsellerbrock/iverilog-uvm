module p07_11_const_size_type;
  typedef logic [16:1] Word;
  localparam int SW = $size(Word);
  initial $display("ST %0d", SW);
endmodule
