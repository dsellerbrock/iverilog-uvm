`timescale 1ns/1ps

module true_timezero_oscillator;
  bit a = 0;
  bit b = 0;
  always @(a) b = ~b;
  always @(b) a = ~a;
  initial begin
    // The #0 lets both always processes subscribe before the first edge.
    #0 a = 1;
    #1;
    $fatal(1, "zero-time oscillator incorrectly advanced to #1");
  end
endmodule
