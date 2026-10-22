module p10_10_uconcat;
  int A[3], B[$], C[];
  int q2[$];
  string S[$];
  byte BA[2];
  initial begin
    A = {1, 2, 3};                 $display("U1 %0d %0d %0d", A[0], A[1], A[2]);
    q2 = '{7, 8};
    B = {q2, 9, q2};               $display("U2 %0d %0d %0d", B.size(), B[2], B[4]);
    C = {B, A};                    $display("U3 %0d %0d", C.size(), C[7]);
    B = {};                        $display("U4 %0d", B.size());
    S = {"ab", "c"};               $display("U6 %0d %s", S.size(), S[1]);
    BA = {4'h6, 4'hf};               $display("U7 %h %h", BA[0], BA[1]);
    C = {{8'h01, 8'h02}, 3};         $display("U8 %0d %0d %0d", C.size(), C[0], C[1]);
  end
endmodule
