`timescale 1ns/1ps
`timescale 1ns/100ps
`resetall
module top;
  timeunit 1ns/1ns;
  initial begin
    #1step;
    if ($realtime < 0.000999 || $realtime > 0.001001)
      $fatal(1, "global step %0.6f ns", $realtime);
    $display("PASS");
    $finish;
  end
endmodule
