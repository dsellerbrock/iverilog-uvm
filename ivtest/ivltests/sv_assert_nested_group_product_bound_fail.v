module test;
  bit c1, c2, a=1, b=1, good=1;
  always #1 c1 = ~c1;
  always #2 c2 = ~c2;
  assert property (@(posedge c1) ((a ##1 b)[*32])[*32]
                   |-> @(posedge c2) good);
endmodule
