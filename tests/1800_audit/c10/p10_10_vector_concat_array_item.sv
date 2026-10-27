module p10_10_vector_concat_array_item;
  int C[];
  initial begin
    C = {{8'h01, 8'h02}, 3};
    $display("U8 %0d %0d %0d", C.size(), C[0], C[1]);
  end
endmodule
