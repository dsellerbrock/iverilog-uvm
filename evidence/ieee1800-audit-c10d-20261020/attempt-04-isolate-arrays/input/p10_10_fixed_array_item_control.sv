module p10_10_fixed_array_item_control;
  int A[3], C[];
  initial begin
    A = {1, 2, 3};
    C = {A};
    $display("F %0d %0d %0d", C.size(), C[0], C[2]);
  end
endmodule
