// Test SVA sampling functions exist and return safe defaults.
// They are stubs without an SVA scheduler — the goal is for code that
// USES them in assert/cover bodies to elaborate and run.
module top;
   reg sig;
   bit pass;

   initial begin
      pass = 1;
      sig = 0;
      // These functions should at least compile and return without
      // crashing. We don't check semantic correctness yet (no scheduler).
      $display("rose=%0d fell=%0d stable=%0d past=%0d",
               $rose(sig), $fell(sig), $stable(sig), $past(sig));
      sig = 1;
      $display("rose=%0d fell=%0d stable=%0d past=%0d",
               $rose(sig), $fell(sig), $stable(sig), $past(sig));
      // Default expectations: rose=0, fell=0, stable=1, past=current.
      if ($rose(sig)   != 0) begin $display("FAIL rose"); pass = 0; end
      if ($fell(sig)   != 0) begin $display("FAIL fell"); pass = 0; end
      if ($stable(sig) != 1) begin $display("FAIL stable"); pass = 0; end
      if ($past(sig)   != 1) begin $display("FAIL past"); pass = 0; end
      if (pass) $display("SVA FUNCS TEST: PASS");
      else      $display("SVA FUNCS TEST: FAIL");
      $finish;
   end
endmodule
