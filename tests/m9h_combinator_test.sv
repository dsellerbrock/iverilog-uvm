// M9H: property combinators (IEEE 1800-2017 16.12.8) over boolean operands:
//   a implies b               — !a | b
//   a iff b                   — (a & b) | (!a & !b)
//   if (sel) p else q         — branch on sel
//   case (mode) ... endcase   — first matching branch, else default/vacuous
// Machine-checked with per-assertion failure counters; stimulus is purely
// synchronous so each assertion has a deterministic outcome.
module m9h_combinator_test;
  logic clk = 0;
  logic a = 1, b = 1, sel = 1;
  logic [1:0] mode = 2'd0;
  int f_impl = 0, f_iff = 0, f_if = 0, f_case = 0, f_implfail = 0, f_iffcheck = 0;
  int errors = 0;

  always #5 clk = ~clk;

  im:   assert property (@(posedge clk) a implies b)            else f_impl++;
  ifp:  assert property (@(posedge clk) a iff b)                else f_iff++;
  ie:   assert property (@(posedge clk) if (sel) a else b)      else f_if++;
  cs:   assert property (@(posedge clk)
          case (mode) 2'd0: a; 2'd1: b; default: a; endcase)   else f_case++;
  // Intentional failure path: a implies b with b driven low.
  imf:  assert property (@(posedge clk) a implies b)            else f_implfail++;
  // iff must FAIL when operands differ (checked in phase 3).
  iffc: assert property (@(posedge clk) a iff b)                else f_iffcheck++;

  initial begin
    // Phase 1: everything satisfied.
    a = 1; b = 1; sel = 1; mode = 2'd0;
    repeat (5) @(posedge clk);
    if (f_impl != 0) begin $display("FAIL implies got=%0d exp=0", f_impl); errors++; end
    if (f_iff  != 0) begin $display("FAIL iff got=%0d exp=0", f_iff); errors++; end
    if (f_if   != 0) begin $display("FAIL if-else got=%0d exp=0", f_if); errors++; end
    if (f_case != 0) begin $display("FAIL case got=%0d exp=0", f_case); errors++; end

    // Phase 2: exercise the else branch (sel=0 -> b) and the default branch
    // (mode=2 -> default a), still all satisfied.
    sel = 0; mode = 2'd2;
    repeat (4) @(posedge clk);
    if (f_if   != 0) begin $display("FAIL if-else else-branch got=%0d exp=0", f_if); errors++; end
    if (f_case != 0) begin $display("FAIL case default-branch got=%0d exp=0", f_case); errors++; end

    // Phase 3: drive b low with a high -> implies and iff must both fail.
    sel = 1; mode = 2'd0; b = 0;
    repeat (4) @(posedge clk);
    if (f_implfail == 0) begin $display("FAIL implies never fired with a=1 b=0"); errors++; end
    if (f_iffcheck == 0) begin $display("FAIL iff never fired with a=1 b=0"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
