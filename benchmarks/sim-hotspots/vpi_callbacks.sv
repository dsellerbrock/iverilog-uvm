`timescale 1ns/1ps
module top;
  reg signal;
  integer i;
  initial begin
    signal = 0;
    $watch_value_changes(signal);
    for (i = 0; i < 10000; i = i + 1) begin
      #1 signal = ~signal;
    end
    $report_value_changes;
    $finish;
  end
endmodule
