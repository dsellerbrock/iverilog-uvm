module top;
  task automatic t(ref static int x); endtask
  task automatic u(); int a; t(a); endtask
endmodule
