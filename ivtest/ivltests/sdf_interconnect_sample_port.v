`timescale 1ns/1ps
module leaf(input wire in, output wire out);
  assign out = in;
endmodule

module dut(input wire a, output wire b);
  leaf u(.in(a), .out(b));
endmodule

module top;
  reg drive;
  logic src;
  always_comb begin
    src = 1'b0;
    src = drive;
  end
  wire result;
  dut d(.a(src), .b(result));
  initial begin
    $sdf_annotate("ivltests/sdf_interconnect_sample_port.sdf", d);
    $monitor("t=%0t src=%b result=%b", $realtime, src, result);
    #5 drive = 0;
    #10 drive = 1;
    #1 $finish;
  end
endmodule
