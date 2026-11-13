`timescale 1ns/1ps
module top;
  task first_format;
    $timeformat(-9, 2, " ns", 10);
  endtask
  initial begin
    $check_timeformat;
    first_format;
    $check_timeformat;
    $timeformat(-6, 1, " us", 8);
    $check_timeformat;
    first_format;
    $check_timeformat;
    $timeformat;
    $check_timeformat;
    $finish(0);
  end
endmodule
