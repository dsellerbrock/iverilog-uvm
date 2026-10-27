module q11_02_qk;
  int A[3] = '{1,2,3}, C[3] = '{1,9,3}, D[3];
  initial begin
    D = 1 ? A : C;
    $display("QK %0d", D[1]);
  end
endmodule
