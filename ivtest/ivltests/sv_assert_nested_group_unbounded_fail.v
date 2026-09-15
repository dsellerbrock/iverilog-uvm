module test;
  bit c1, c2, a=1, b=1, good=1;
  always #10 c1 = ~c1;
  always #15 c2 = ~c2;
  assert property (@(posedge c1) ((a ##1 b)[*1:2])[*1:$]
                   |-> @(posedge c2) good);
endmodule
