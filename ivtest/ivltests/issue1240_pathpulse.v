// IEEE 1800-2023 30.7.1: PATHPULSE$ specparams set the pulse limits of
// module paths. A pulse narrower than the reject limit is filtered, a
// pulse between the reject and error limits becomes X, and a wider one
// passes. PATHPULSE$<in>$<out> overrides the module-wide PATHPULSE$.
`timescale 1ns/1ns

// The issue's case: reject 2, error 3, path delay 4.
module b(input a, output y);
  assign y = a;
  specify
    specparam PATHPULSE$a$y = (2, 3);
    (a => y) = 4;
  endspecify
endmodule

// Module-wide limits; one value is both limits (reject = error = 1).
module g(input a, output y);
  assign y = a;
  specify
    specparam PATHPULSE$ = 1;
    (a => y) = 4;
  endspecify
endmodule

// The per-path entry (reject 0) overrides the module-wide one (reject 4)
// for a => y only.
module o(input a, input c, output y, output z);
  assign y = a;
  assign z = c;
  specify
    specparam PATHPULSE$ = (4, 4);
    specparam PATHPULSE$a$y = (0, 0);
    (a => y) = 4;
    (c => z) = 4;
  endspecify
endmodule

module issue1240_pathpulse;
  reg a = 0;
  wire y, gy, oy, oz;
  b ub(a, y);
  g ug(a, gy);
  o uo(a, a, oy, oz);
  always @(y)  $display("%0t y=%b",  $time, y);
  always @(gy) $display("%0t gy=%b", $time, gy);
  always @(oy) $display("%0t oy=%b", $time, oy);
  always @(oz) $display("%0t oz=%b", $time, oz);
  initial begin
    #10 a = 1; #1 a = 0;     // width 1
    #20 a = 1; #2 a = 0;     // width 2
    #20 a = 1; #5 a = 0;     // width 5
    #40 $finish;
  end
endmodule
