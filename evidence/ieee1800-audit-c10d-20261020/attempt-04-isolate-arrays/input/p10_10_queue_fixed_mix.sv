module p10_10_queue_fixed_mix;
  int A[3], B[$], C[];
  int q2[$];
  initial begin
    A = {1, 2, 3};
    q2 = '{7, 8};
    B = {q2, 9, q2};
    C = {B, A};
    $display("U3 %0d %0d", C.size(), C[7]);
  end
endmodule
