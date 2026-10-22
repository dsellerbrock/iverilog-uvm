module p07_11_query_runtime_type;
  typedef logic [16:1] Word;
  Word Ram[0:9];
  initial $display("R %0d %0d", $size(Word), $size(Ram,2));
endmodule
