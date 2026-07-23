// SVA property combinators (IEEE 1800-2017 16.12.8) over boolean operands:
//   a implies b               -> !a | b
//   a iff b                   -> (a & b) | (!a & !b)
//   if (sel) p else q         -> branch on sel
//   case (mode) ... endcase   -> first matching branch, else default/vacuous
// Each collapses to a single boolean property. Self-checking: prints PASSED
// only when every assertion behaved as required under synchronous stimulus.
module sv_property_combinators;
  logic clk = 0;
  logic a = 1, b = 1, sel = 1;
  logic [1:0] mode = 2'd0;
  int f_impl = 0, f_iff = 0, f_if = 0, f_case = 0, f_implfail = 0, f_iffchk = 0;
  int errors = 0;

  always #5 clk = ~clk;

  im:   assert property (@(posedge clk) a implies b)          else f_impl++;
  ifp:  assert property (@(posedge clk) a iff b)              else f_iff++;
  ie:   assert property (@(posedge clk) if (sel) a else b)    else f_if++;
  cs:   assert property (@(posedge clk)
          case (mode) 2'd0: a; 2'd1: b; default: a; endcase) else f_case++;
  imf:  assert property (@(posedge clk) a implies b)          else f_implfail++;
  iffc: assert property (@(posedge clk) a iff b)              else f_iffchk++;

  initial begin
    a = 1; b = 1; sel = 1; mode = 2'd0;
    repeat (5) @(posedge clk);
    if (f_impl != 0) begin $display("FAILED implies got=%0d exp=0", f_impl); errors++; end
    if (f_iff  != 0) begin $display("FAILED iff got=%0d exp=0", f_iff); errors++; end
    if (f_if   != 0) begin $display("FAILED if-else got=%0d exp=0", f_if); errors++; end
    if (f_case != 0) begin $display("FAILED case got=%0d exp=0", f_case); errors++; end

    // else branch (sel=0 -> b) and default branch (mode=2 -> default a).
    sel = 0; mode = 2'd2;
    repeat (4) @(posedge clk);
    if (f_if   != 0) begin $display("FAILED if-else else-branch got=%0d", f_if); errors++; end
    if (f_case != 0) begin $display("FAILED case default-branch got=%0d", f_case); errors++; end

    // b low, a high -> implies and iff must both fail.
    sel = 1; mode = 2'd0; b = 0;
    repeat (4) @(posedge clk);
    if (f_implfail == 0) begin $display("FAILED implies never fired with a=1 b=0"); errors++; end
    if (f_iffchk   == 0) begin $display("FAILED iff never fired with a=1 b=0"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
