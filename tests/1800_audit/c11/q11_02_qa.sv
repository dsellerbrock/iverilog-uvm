module q11_02_qa;
  int A[3] = '{1,2,3}, C[3] = '{1,9,3}, D[3];
  bit c;
  initial begin
    c = 1; D = c ? A : C;
    $display("QA %0d", D[1]);
  end
endmodule
