`timescale 1ns/1ps
module issue1715_modpath_dut(input logic a, input logic [1:0] mode,
                             output wire y);
  assign y = a;
  specify
    if (mode[1]) (a => y) = (1, 7);
    if (!mode[1]) (a => y) = (4, 3);
  endspecify
endmodule

module issue1715_modpath_condition;
  logic a = 0;
  logic [1:0] mode = 0;
  wire y;
  time start;

  issue1715_modpath_dut dut(a, mode, y);

  initial begin
    #10;
    start = $time;
    mode = 2;
    a = 1;
    wait (y === 1'b1);
    if (($time - start) != 1)
      $fatal(1, "ISSUE1715 expected 1ns path delay, got %0t", $time-start);
    $display("PASSED");
    $finish;
  end
endmodule
