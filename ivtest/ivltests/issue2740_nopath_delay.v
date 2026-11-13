// IEEE 1800-2023 30.5.3 selects the delay from the active module paths
// "when a specify path output is to be scheduled to transition". An
// output change caused by an input with no path to the output is
// scheduled that delay from now (user ruling 2026-11-10 on #2740). A
// change a path input caused keeps 30.6: the larger of the path delay
// and the distributed delay, measured from the path input.
`timescale 1ns/1ns

// The issue's case: C has no path to Y.
module c1(input A, input C, output Y);
  assign Y = A ^ C;
  specify (A => Y) = (6, 9); endspecify
endmodule

// Two paths: C's change takes the delay of the most recent path input.
module c2(input A, input B, input C, output Y);
  assign Y = A ^ B ^ C;
  specify (A => Y) = (6, 9); (B => Y) = (5, 11); endspecify
endmodule

// Figure 30-4: distributed delays 10 + 20 exceed the path delay of 22.
module f4(input D, output Q);
  wire n;
  buf #10 (n, D);
  buf #20 (Q, n);
  specify (D => Q) = 22; endspecify
endmodule

// Figure 30-3: distributed delays 0 + 1, path delay 22.
module f3(input D, output Q);
  wire n;
  buf #0 (n, D);
  buf #1 (Q, n);
  specify (D => Q) = 22; endspecify
endmodule

module issue2740_nopath_delay;
  reg a = 0, b = 0, c = 0, d = 0, e = 0, g = 0, h = 0;
  wire y, y2, q4, q3;
  c1 u1(a, c, y);
  c2 u2(e, g, h, y2);
  f4 u4(d, q4);
  f3 u3(d, q3);
  always @(y)  $display("%0t y=%b", $time, y);
  always @(y2) $display("%0t y2=%b", $time, y2);
  always @(q4) $display("%0t q4=%b", $time, q4);
  always @(q3) $display("%0t q3=%b", $time, q3);
  initial begin
    #20 a = 1;          // A: rise 6 -> 26
    #20 c = 1;          // C, no path: fall 9 from now -> 49
    #20 c = 0;          // rise 6 from now -> 66
    #20 a = 0; c = 1;   // A and C together: Y stays 1
    #20 c = 0;          // A changed after Y's last change, so this
                        // counts as path-caused: max(100, 80 + 9) = 100
                        // (ruling 2026-11-10, 30.6 kept exact)
    #40 $finish;
  end
  initial begin
    #20 g = 1;          // B: rise 5 -> 25
    #20 h = 1;          // C, no path: B is active, fall 11 -> 51
  end
  initial #50 d = 1;    // Q: 30 after D (30.6 example 2), 22 (example 1)
endmodule
