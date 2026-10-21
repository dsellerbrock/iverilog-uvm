module tb;
  int q1[$] = '{1,2};
  int q2[$];
  initial begin
    q2 = q1;
    q1[0] = 9;
    $display("A2 %0d", q2[0]);
  end
endmodule
