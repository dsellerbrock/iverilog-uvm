// A `rand` enum property referenced by BOTH the auto-synthesized enum `inside`
// constraint and a user constraint was emitted to the Z3 constraint IR with two
// different widths: the auto-inside used the enum's packed width (e.g. 2) while
// the generic property reference defaulted to 32 (an enum is not a netvector, so
// it fell through the width computation).  get_prop_var dedupes by property
// index with the first width winning, so the second emission was silently
// truncated -- corrupting the solver state ("vvp_z3: internal error: prop idx=N
// width mismatch").  A user constraint on a rand enum could then be solved
// against a wrong-width variable and produce an out-of-range / constraint-
// violating value.
//
// Fix: the generic constraint-IR width computation now handles a netenum
// property using the enum's packed width, matching the auto-inside emission.
typedef enum bit [1:0] { S0 = 0, S1 = 1, S2 = 2, S3 = 3 } st_e;

class c;
  rand st_e a;
  rand st_e b;
  // user constraints that reference the rand enum properties
  constraint c_a { a != S0; a != S3; }     // a must be S1 or S2
  constraint c_b { b == S3; }              // b pinned
endclass

module rand_enum_constraint_width_test;
  initial begin
    c obj = new();
    int ok = 1;
    for (int i = 0; i < 40; i++) begin
      if (!obj.randomize()) begin ok = 0; $display("randomize failed @%0d", i); break; end
      // value must be a valid enum AND satisfy the constraints
      if (!(obj.a inside {S1, S2})) begin ok = 0; $display("FAIL a=%0d (want S1/S2)", obj.a); break; end
      if (obj.b !== S3)            begin ok = 0; $display("FAIL b=%0d (want S3)", obj.b); break; end
    end
    if (ok) $display("PASS");
    $finish;
  end
endmodule
