// IEEE 1800-2023 17.7 / 17.7.1: illegal uses of free checker variables.
checker bad(bit a, b, event clk);
  rand bit x, y, z;
  rand const bit c;
  assign x = a & b;          // error: continuous assignment
  always_comb y = a & b;     // error: blocking assignment
  always_ff @clk z <= a & b; // OK
  always_ff @clk c <= a;     // error: constant free variable assigned
endchecker

module sva_checker_free_fail;
  rand bit m;                // error: `rand' outside a checker
  bit a, b;
  event e;
  bad u(a, b, e);
endmodule
