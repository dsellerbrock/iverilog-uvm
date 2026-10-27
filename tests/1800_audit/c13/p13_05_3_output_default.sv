module top; int g;
  task automatic t1(output int o = g); o = 42; endtask
  initial begin t1(); $display("%s 13.5.3.output_default_binds g=%0d", g == 42 ? "PASS" : "FAIL", g); end
endmodule
