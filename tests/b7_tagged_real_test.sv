// Phase 63b/B7 (gap close): tagged-union constructor + `case matches`
// pattern matching with runtime tag tracking via companion NetNet.
//
// IEEE 1800-2017 §6.13 (tagged unions) + §12.6 (pattern matching).
//
// Coverage:
//   T1, T2: tagged-constructor expression (commit d6fd9c199)
//   T3: case-matches dispatches to the correct branch based on the
//       last-written tag — exercises companion NetNet allocation
//       at variable declaration, set on member writes, and read in
//       case dispatch.
`timescale 1ns/1ps

module top;
  typedef union tagged {
    int   a;
    int   b;
    int   c;
  } my_tu;

  int hits_a, hits_b, hits_c, hits_default;

  initial begin
    my_tu u;

    u = tagged a 42;
    if (u.a !== 42) $fatal(1, "FAIL/T1: expected 42 got %0d", u.a);

    u = tagged c 8'hAB;
    if (u.c !== 8'hAB) $fatal(1, "FAIL/T2: expected ab got %0h", u.c);

    // T3: write tag b, dispatch via case-matches
    hits_a = 0; hits_b = 0; hits_c = 0; hits_default = 0;
    u = tagged b 100;
    case (u) matches
      tagged a: hits_a = 1;
      tagged b: hits_b = 1;
      tagged c: hits_c = 1;
      default:  hits_default = 1;
    endcase
    if (hits_a || !hits_b || hits_c || hits_default)
      $fatal(1, "FAIL/T3: expected only hits_b=1, got a=%0d b=%0d c=%0d d=%0d",
             hits_a, hits_b, hits_c, hits_default);

    // T4: write tag a, dispatch
    hits_a = 0; hits_b = 0; hits_c = 0;
    u = tagged a 7;
    case (u) matches
      tagged a: hits_a = 1;
      tagged b: hits_b = 1;
      tagged c: hits_c = 1;
    endcase
    if (!hits_a || hits_b || hits_c)
      $fatal(1, "FAIL/T4: expected hits_a=1, got a=%0d b=%0d c=%0d",
             hits_a, hits_b, hits_c);

    // T5: switch tag mid-stream — case-matches must follow the last write
    u = tagged b 50;
    u = tagged c 200;
    hits_a = 0; hits_b = 0; hits_c = 0;
    case (u) matches
      tagged a: hits_a = 1;
      tagged b: hits_b = 1;
      tagged c: hits_c = 1;
    endcase
    if (hits_a || hits_b || !hits_c)
      $fatal(1, "FAIL/T5: expected hits_c=1 after b->c, got a=%0d b=%0d c=%0d",
             hits_a, hits_b, hits_c);

    $display("PASS: tagged-union constructor + case matches dispatch");
    $finish;
  end
endmodule
