`timescale 1ns/1ps
module top;
  reg [1023:0] a, b, acc;
  integer i;
  initial begin
    a = {32{32'h9e3779b9}};
    b = {32{32'h7f4a7c15}};
    acc = 0;
    for (i = 0; i < 4096; i = i + 1) begin
      acc = ((a ^ b) + (a << (i % 31))) ^ (b >> (i % 29));
      a = {a[1015:0], a[1023:1016]} + i;
      b = {b[1021:0], b[1023:1022]} ^ (i * 32'h1021);
    end
    $display("wide=%h", acc);
    $finish;
  end
endmodule
