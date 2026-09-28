`timescale 1ns/1ps
module tb;
  logic clk = 0, rst_n = 0, zeroize = 0;
  logic [1:0] x [45:0], s [45:0];
  logic [45:0] rnd, rnd_for_Boolean0, rnd_for_Boolean1;
  integer hash = 0;
  abr_masked_A2B_conv #(.WIDTH(46)) dut (.*);
  always #5 clk = ~clk;
  initial begin
    for (int k = 0; k < 46; k++) x[k] = 0;
    rnd = 0; rnd_for_Boolean0 = 0; rnd_for_Boolean1 = 0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    for (int n = 0; n < 100; n++) begin
      for (int k = 0; k < 46; k++) x[k] = (n * 17 + k * 23) >> (k % 4);
      rnd = n * 32'h31415926;
      rnd_for_Boolean0 = n * 32'h9e3779b9;
      rnd_for_Boolean1 = n * 32'h7f4a7c15;
      zeroize = (n % 37 == 0);
      @(negedge clk);
      for (int k = 0; k < 46; k++) hash = ((hash << 5) ^ (hash >> 2)) ^ s[k];
    end
    $display("hash=%08h", hash);
    $finish;
  end
endmodule
