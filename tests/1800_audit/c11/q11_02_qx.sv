module q11_02_qx;
  logic c = 1'bx;
  int A[2] = '{1,5}, C[2] = '{1,7}, D[2];
  initial begin
    D = c ? A : C;
    $display("QX %0d %b", D[0], D[1]);
  end
endmodule
