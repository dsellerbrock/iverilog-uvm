`timescale 1ns/1ps
module top;
  reg [31:0] memory [0:16383];
  reg [31:0] sum;
  integer i;
  initial begin
    $readmemh(".inputs/large_memory.hex", memory);
    sum = 0;
    for (i = 0; i < 524288; i = i + 1) begin
      memory[(i * 13) & 16383] = memory[(i * 13) & 16383] ^ i;
      sum = sum + memory[(i * 29) & 16383];
    end
    $display("memory=%h", sum);
    $finish;
  end
endmodule
