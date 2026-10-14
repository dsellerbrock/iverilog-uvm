`timescale 1ns/1ps
module top;
  reg clk;
  reg [31:0] data;
  integer i;
  initial begin
    if ($test$plusargs("use_fst")) $dumpfile("waveform.fst");
    else $dumpfile("waveform.vcd");
    $dumpvars(0, top);
    clk = 0;
    data = 0;
    for (i = 0; i < 32000; i = i + 1) begin
      #1 clk = ~clk;
      data = {data[30:0], data[31]} ^ (i * 32'h01020305);
    end
    $display("wave=%08h", data);
    $finish;
  end
endmodule
