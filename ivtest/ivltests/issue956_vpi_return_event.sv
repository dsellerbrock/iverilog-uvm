`timescale 1ns/1ps
module top;
  reg applied = 0;
  reg canceled = 0;
  reg immediate = 0;

  initial begin
    $issue956_schedule(applied, canceled, immediate);
    #6;
    $issue956_check(applied, canceled, immediate);
    $finish;
  end
endmodule
