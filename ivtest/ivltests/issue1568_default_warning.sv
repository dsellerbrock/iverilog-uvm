`timescale 1ns/1ps

module issue1568_driver(input wire a, output wire y);
  assign y = a;
endmodule

module issue1568_receiver(input wire a);
  always @(posedge a) $display("%m at %0t", $time);
endmodule

module tb;
  reg stimulus = 0;
  wire driven, other;
  issue1568_driver source(stimulus, driven);
  issue1568_driver unrelated(stimulus, other);
  issue1568_receiver mismatch(driven);
  issue1568_receiver missing(driven);
  issue1568_receiver valid(driven);

  initial begin
    $sdf_annotate("ivltests/issue1568_default_warning.sdf", tb);
    #10 stimulus = 1;
    #10 $finish;
  end
endmodule
