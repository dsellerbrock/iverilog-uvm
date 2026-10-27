module top;
  byte b;
  task automatic t(ref int x); endtask
  initial t(b);
endmodule
