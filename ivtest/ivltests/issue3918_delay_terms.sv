`timescale 1ns/1ns

module scalar_dut(input wire a, output wire y, q);
  assign y = ~a;
  assign #5 q = ~a;
  specify
    (a => y) = 5;
  endspecify
endmodule

module vector_dut(input wire [1:0] a, input wire en, alt,
                  output wire [1:0] y);
  assign y = {a[1], ~a[0]};
  specify
    if (en) (a *> y) = (3, 5, 4);
    if (alt) (a *> y) = 7;
  endspecify
endmodule

module top;
  reg a = 0;
  reg [1:0] bus = 2'b00;
  reg en = 1, alt = 0;
  wire y, q;
  wire [1:0] vector_y;
  scalar_dut scalar_path(a, y, q);
  vector_dut vector_path(bus, en, alt, vector_y);

  initial begin
    #10 a = 1;
    bus = 2'b11;
    #1 $issue3918_sample;  // 11: both paths are still pending.
    #3 $issue3918_sample;  // 14: only the vector rise has arrived.
    #2 force scalar_path.y = 1'b1;
    $issue3918_sample;     // 16: the force masks the stage's output.
    #3 release scalar_path.y;
    #1 en = 0;
    bus = 2'bzx;
    $issue3918_sample;     // 20: neither conditional path applies.
    #1 $finish(0);
  end
endmodule
