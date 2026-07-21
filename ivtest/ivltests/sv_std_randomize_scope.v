// IEEE 1800-2017 18.12: std::randomize(vars) — the scope (non-class) form.
// The expression form previously returned success WITHOUT assigning the
// variables (silent no-randomization). It now assigns each integral
// variable an unconstrained random value and returns 1.
module sv_std_randomize_scope;
  int a, b;
  logic [63:0] w;
  int errors = 0;
  int all_zero = 0;
  initial begin
    for (int i = 0; i < 40; i++) begin
      a = 0; b = 0; w = 0;
      if (!std::randomize(a, b, w)) begin $display("FAIL: returned 0"); errors++; end
      if (a == 0 && b == 0 && w == 0) all_zero++;
    end
    // 40 draws of 128 random bits: all-zero every time is effectively
    // impossible, so a non-zero count proves the variables are written.
    if (all_zero == 40) begin $display("FAIL: variables never changed"); errors++; end
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d)", errors);
  end
endmodule
