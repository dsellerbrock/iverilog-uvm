`timescale 1ns/1ps
module sdf_conditional_iopath_dut(input A, input mode, output Y);
  buf (Y, A);
  specify
    if (mode) (A => Y) = 0;
    ifnone (A => Y) = 0;
  endspecify
endmodule

module sdf_conditional_iopath;
  reg A = 0;
  reg mode = 1;
  wire Y;
  sdf_conditional_iopath_dut dut(A, mode, Y);

  always @(Y) $display("Y %0t %b", $time, Y);

  initial begin
    $sdf_annotate("ivltests/sdf_conditional_iopath.sdf", dut);
    #10 A = 1;
    #20 mode = 0;
    #1 A = 0;
  end
endmodule
