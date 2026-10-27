module top; int g = 5;
  task automatic t3(inout int io = g); io = io + 1; endtask
  initial begin t3(); $display("%s 13.5.3.inout_default g=%0d", g == 6 ? "PASS" : "FAIL", g); end
endmodule
