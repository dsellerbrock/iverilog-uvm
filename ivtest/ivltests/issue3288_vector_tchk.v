// IEEE 1800-2023 31.8: a vector terminal is one timing check; a
// transition of one or more bits is a single transition of the vector.
`timescale 1ns/1ns
module issue3288_vector_tchk_dut #(parameter W = 1)
  (input [1:0] c, input [1:0] w, input d, input [1:0] e, input [W-1:0] p,
   input [1:0] b);
  reg ntf = 0;
  specify
    $width(posedge c, 5);
    $setup(d, posedge w, 3, ntf);
    $hold(edge [01] e, d, 3);
    $width(negedge p, 5);
    $width(posedge b[1], 5);
  endspecify
endmodule

module issue3288_vector_tchk;
  reg [1:0] c = 0, w = 0, e = 0, b = 0;
  reg [2:0] p = 3'b111;
  reg d = 0;
  issue3288_vector_tchk_dut #(.W(3)) u(c, w, d, e, p, b);
  initial begin
    #10 c = 2'b11; #2 c = 2'b00;   // both bits pulse: one $width violation
    #8  d = 1;     #1 w = 2'b11;   // both bits rise: one $setup violation
    #4  $display("notifier %b", u.ntf); // toggled once
    #5  e = 2'b11; #1 d = 0;       // edge [01] on both bits: one $hold
    #9  p = 3'b011; #2 p = 3'b111; // bit 2 only, width from W = 3
    #8  b = 2'b10; #2 b = 2'b00;   // bit-select terminal
    #10 $finish;
  end
endmodule
