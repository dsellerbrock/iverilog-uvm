// Phase 63b / B8: surface a one-time advisory when std::randomize(...)
// with-clause is parsed but the runtime stub doesn't enforce it.
//
// C6 (Phase 62) made the form parse so real testbenches don't fail
// to compile.  But the with-clause constraints are silently dropped
// — the call returns 1 and ignores the user's predicate.  Real fix
// needs std::randomize lowering through the same Z3 constraint
// solver path as obj.randomize() with{}; that's a separate larger
// item.
`timescale 1ns/1ps

module top;
  initial begin
    int x;
    // `std` is not pre-registered as a package, so std::randomize
    // hits the C6 statement-level rule that captures-and-drops the
    // with-clause.  Phase 63b/B8 emits a one-time advisory here.
    std::randomize(x) with { x > 0; x < 10; };
    $display("PASS: std::randomize(x) with{...} compiles with advisory warning");
    $finish;
  end
endmodule
