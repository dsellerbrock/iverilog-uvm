module tb;
  int a[2];
  initial foreach (a[i]) ;
  initial $display("escaped=%0d", i);
endmodule
