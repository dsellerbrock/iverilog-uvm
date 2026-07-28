// Phase 63b / B8 follow-up: the statement form now reaches the same
// Z3-backed scope-randomize path as the expression form. This former
// advisory probe remains as a compile/run smoke test.
`timescale 1ns/1ps

module top;
  initial begin
    int x;
    std::randomize(x) with { x > 0; x < 10; };
    if (x <= 0 || x >= 10)
      $fatal(1, "FAIL: solver ignored with-clause, x=%0d", x);
    $display("PASS: std::randomize(x) with{...} uses solver");
    $finish;
  end
endmodule
