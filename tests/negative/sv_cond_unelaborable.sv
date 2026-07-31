// A condition expression that will not elaborate.
//
// In SystemVerilog mode this hits a "compile-progress" fallback that
// ASSUMES THE CONDITION FALSE: the then-branch is deleted and the
// else-branch is compiled in its place. Until this file, the compile
// then SUCCEEDED -- it built, it ran, and it took the else-branch,
// printing the wrong answer with only a warning to say why.
//
// It fails now because the expression INSIDE the condition counts an
// error of its own: PEAssignPattern in a context that gives it no type
// used to warn and return null without counting anything, so nothing
// downstream knew the condition had failed for a real reason.
//
// The fallback itself is still there and still prints its warning here.
// Two sites in the UVM library depend on it (uvm_comparer.svh:638,
// uvm_driver.svh:100); removing it fails the entire 229-test UVM suite
// at exactly those two lines. So a condition that fails for a reason
// nothing else reports STILL loses its then-branch silently. This test
// pins the half that is fixed and marks the half that is not.
module sv_cond_unelaborable;
  logic [7:0] x;
  initial begin
    if ('{1, 2})
      x = 8'hAA;
    else
      x = 8'h55;
    $display("FAILED -- should not have compiled, x = %h", x);
  end
endmodule
