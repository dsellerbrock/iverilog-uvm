module top;
  task automatic t(ref int x); fork x = 1; join_any endtask
  int g;
  initial t(g);
endmodule
