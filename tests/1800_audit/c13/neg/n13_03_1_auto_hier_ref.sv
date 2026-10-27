module top;
  task automatic t(); int a; endtask
  initial $display(t.a);
endmodule
