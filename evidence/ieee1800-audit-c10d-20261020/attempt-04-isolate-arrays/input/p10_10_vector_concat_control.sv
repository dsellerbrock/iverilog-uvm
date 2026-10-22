module p10_10_vector_concat_control;
  int value;
  initial begin
    value = {8'h01, 8'h02};
    $display("V %0d", value);
  end
endmodule
