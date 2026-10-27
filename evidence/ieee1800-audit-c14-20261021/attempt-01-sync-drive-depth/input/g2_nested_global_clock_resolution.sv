`timescale 1ns/1ps
module top;
  subsystem1 sub1();
  subsystem2 sub2();
  initial begin
    #31;
    $display("COUNTS %0d %0d", sub1.common.count, sub2.common.count);
    $finish;
  end
endmodule

module subsystem1;
  logic subclk1 = 0;
  always #5 subclk1 = ~subclk1;
  global clocking sub_sys1 @(posedge subclk1);
  endclocking
  common_sub common();
endmodule

module subsystem2;
  logic subclk2 = 0;
  always #10 subclk2 = ~subclk2;
  global clocking sub_sys2 @(posedge subclk2);
  endclocking
  common_sub common();
endmodule

module common_sub;
  integer count = 0;
  always @($global_clock) count = count + 1;
endmodule
