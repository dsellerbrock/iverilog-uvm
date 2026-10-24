module d4_inout_variable_default;
  int gv;
  task automatic u(inout int io = gv); io = io + 1; endtask
  initial begin gv = 5; u(); $display("D4 gv=%0d", gv); end
endmodule
