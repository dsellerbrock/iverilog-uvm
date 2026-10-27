module q11_02_qs;
  typedef struct { int a; byte b; } S;
  S s1 = '{1, 2}, s3 = '{1, 3}, s4;
  bit c;
  initial begin
    c = 0; s4 = c ? s1 : s3;
    $display("QS %0d", s4.b);
  end
endmodule
