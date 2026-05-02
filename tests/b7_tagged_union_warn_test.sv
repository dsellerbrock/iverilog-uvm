// Phase 63b / B7: surface a one-time warning when a `union tagged`
// is declared, since tag-enforcement semantics are not yet
// implemented.
//
// I6 (Phase 62) made `union tagged { ... }` parse so that real
// testbenches don't hit a syntax error.  But the tag isn't enforced
// — reads via .member can return data from the wrong member.  This
// commit emits a one-shot warning at declaration time so users know
// the semantics are degraded.
`timescale 1ns/1ps

module top;
  typedef union tagged {
    int   a;
    real  b;
    logic [7:0] c;
  } my_tu;

  initial begin
    my_tu u;
    u.a = 42;  // Pre-fix: no warning, no enforcement.
    if (u.a != 42) $fatal(1, "FAIL: read-back");
    $display("PASS: tagged union compiles with one-time advisory warning");
    $finish;
  end
endmodule
