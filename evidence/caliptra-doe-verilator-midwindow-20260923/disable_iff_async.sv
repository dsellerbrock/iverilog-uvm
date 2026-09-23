`timescale 1ns/1ps
module tb;
  bit clk = 0;
  always #5 clk = ~clk;
  bit rst = 0;
  bit mid_start = 0;
  bit mid_status = 0;
  bit boundary_start = 0;
  bit boundary_status = 0;
  bit held_start = 0;
  bit long_start = 0;
  bit long_status = 0;
  bit negative_start = 0;
  bit negative_status = 0;
  integer mid_failures = 0;
  integer control_failures = 0;
  integer boundary_failures = 0;
  integer held_failures = 0;
  integer long_failures = 0;
  integer negative_failures = 0;

  a_mid: assert property (@(posedge clk) disable iff (rst) mid_start |=> mid_status)
    else mid_failures++;
  a_control: assert property (@(posedge clk) mid_start |=> mid_status)
    else control_failures++;
  a_boundary: assert property (@(posedge clk) disable iff (rst) boundary_start |=> boundary_status)
    else boundary_failures++;
  a_held: assert property (@(posedge clk) disable iff (rst) held_start |=> 1'b0)
    else held_failures++;
  a_long: assert property (@(posedge clk) disable iff (rst) long_start |-> ##[2:3] long_status)
    else long_failures++;
  a_negative: assert property (@(posedge clk) disable iff (rst) negative_start |=> negative_status)
    else negative_failures++;

  initial begin
    #45 rst = 1;
    #1 rst = 0;
  end

  initial begin
    #2 mid_start = 1;
    #5 mid_start = 0;
    #4 rst = 1;
    #1 rst = 0;
    #1 mid_start = 1;
    #3;
    #8 mid_status = 1;
    #8 boundary_start = 1;
    #5 boundary_start = 0;
    #9;
    #1 held_start = 1;
    #3 rst = 1;
    #4 held_start = 0;
    #2 rst = 0;
    #7 long_start = 1;
    #5 long_start = 0;
    #1 rst = 1;
    #1 rst = 0;
    #23 negative_start = 1;
    #5 negative_start = 0;
    #13;
    $display("RESULT mid=%0d control=%0d boundary=%0d held=%0d long=%0d negative=%0d",
             mid_failures, control_failures, boundary_failures, held_failures,
             long_failures, negative_failures);
    if (mid_failures != 0 || control_failures != 1 || boundary_failures != 0
        || held_failures != 0 || long_failures != 0 || negative_failures != 1)
      $fatal(1, "disable iff async regression mismatch");
    $finish;
  end
endmodule
