module p10_10_uconcat;
  int A[3], B[$];
  int q2[$];
  string hello;
  string S[$];
  byte BA[2];
  initial begin
    A = {1, 2, 3};                 $display("U1 %0d %0d %0d", A[0], A[1], A[2]);
    q2 = '{7, 8};
    B = {q2, 9, q2};               $display("U2 %0d %0d %0d", B.size(), B[2], B[4]);
    B = {};                        $display("U4 %0d", B.size());
    hello = "ab";
    S = {hello, "c"};               $display("U6 %0d %s", S.size(), S[1]);
    BA = {4'h6, 4'hf};               $display("U7 %h %h", BA[0], BA[1]);
  end
endmodule
