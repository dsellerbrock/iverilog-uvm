`timescale 1ns/1ps
interface timing_if(input wire a, output wire y);
  assign y = a;
  specify
    specparam rise = 3, fall = 5;
    (a => y) = (rise, fall);
  endspecify
endinterface

module timing_module(input wire a, output wire y);
  assign y = a;
  specify
    (a => y) = (3, 5);
  endspecify
endmodule

module top;
  reg a = 0;
  wire y, ym;
  timing_if intf(a, y);
  timing_module dut(a, ym);
  initial begin
    if (!$issue1299_vpi_check()) $fatal(1, "path ownership incorrect");
    #10 a = 1;
    #2 if (y !== 0 || ym !== 0) $fatal(1, "rise early");
    #1.1 if (y !== 1 || ym !== 1) $fatal(1, "rise late");
    #7 a = 0;
    #4 if (y !== 1 || ym !== 1) $fatal(1, "fall early");
    #1.1 if (y !== 0 || ym !== 0) $fatal(1, "fall late");
    $display("PASS interface specify\nPASSED");
    $finish(0);
  end
endmodule
