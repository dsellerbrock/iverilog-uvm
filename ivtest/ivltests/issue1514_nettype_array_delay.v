`timescale 1ns/1ps
nettype logic bit_t;

module tb;
  logic src[0:1];
  bit_t arr[0:1];

  assign #2 arr = src;

  initial begin
    src[0] = 0;
    src[1] = 0;
    #4;
    #1 src[1] = 1;
    #1;
    if ({arr[0], arr[1]} !== 2'b00)
      $fatal(1, "nettype array changed before its assignment delay");
    $display("nettype array remains unchanged before delay");
    #1;
    if ({arr[0], arr[1]} !== 2'b01)
      $fatal(1, "nettype array did not change after its assignment delay");
    $display("nettype array changed after assignment delay");
    $finish;
  end
endmodule
