// Phase 63b/B7 (real impl): tagged-union constructor expression
// `tagged Tag value` must parse as a real SystemVerilog expression
// and assign the named member.
//
// IEEE 1800-2017 §6.13.  Pre-fix: `tagged a 42` was a syntax error,
// blocking real testbenches from compiling.  Now lowered to a named
// assignment-pattern: equivalent to `'{a:42}` for plain unions, which
// sets the member to the value.  Tag tracking and `case ... matches`
// pattern destructure are separate (still gapped) items.
`timescale 1ns/1ps

module top;
  typedef union tagged {
    int   a;
    real  b;
    logic [7:0] c;
  } my_tu;

  initial begin
    my_tu u;

    u = tagged a 42;
    if (u.a !== 42) $fatal(1, "FAIL/T1: expected 42 got %0d", u.a);

    u = tagged c 8'hAB;
    if (u.c !== 8'hAB) $fatal(1, "FAIL/T2: expected ab got %0h", u.c);

    $display("PASS: tagged-union constructor lowers to named member assignment");
    $finish;
  end
endmodule
