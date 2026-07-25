// M9-9: free (`rand`) variables inside a checker (IEEE 1800-2017 17.9) are
// not supported. A checker's rand variable is a nondeterministic value the
// solver may choose per evaluation, which the assertion engine has no way to
// model, so it must be rejected rather than quietly treated as an ordinary
// variable holding x.
//
// This gap was NOT listed among M9-9's residuals; probing the clause turned
// it up. It is loud already -- this pins it so it stays loud.
checker chk_free(input logic clk, logic x);
  rand logic fv;
  assert property (@(posedge clk) x |-> fv);
endchecker

module checker_free_variable;
  logic clk = 0, x = 1;
  chk_free u(clk, x);
  initial begin
    #5 clk = 1;
    #5 $finish(0);
  end
endmodule
