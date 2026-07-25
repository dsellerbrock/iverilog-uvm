// M9-10: implicit clock inference for a concurrent assertion written in
// procedural code (IEEE 1800-2017 16.14.6).
//
// An `assert property' with no clocking event of its own, in a module with
// no default clocking, used to be a hard error. 16.14.6 says the clock is
// inferred from the enclosing procedural context instead. The inferred
// clock here is the innermost enclosing event control, so:
//
//   - `always @(posedge clk) assert property (p)'  -> posedge clk
//   - `always @(negedge clk) assert property (p)'  -> negedge clk
//   - an inner `@(negedge clk) assert property (p)' inside an outer
//     `always @(posedge clk)' block -> negedge, while an assertion written
//     ABOVE that inner event control still gets the outer posedge.
//
// Each inferred form is compared against the same assertion with the clock
// written explicitly, so "inference happened" is not confused with
// "assertion silently did nothing" -- a dropped assertion reports zero
// failures, which is what a passing assertion also reports.
// A NAMED property reference has no clocking event of its own; the
// declaration may or may not carry one, and the substitution happens after
// the point where inference decides. Both directions are pinned here: an
// early version of the inference parked the reference itself and reported a
// spurious 16.14.6 error for `p_clocked', whose clock is right there in the
// declaration.
module main;

  reg clk = 0;
  reg a = 1;
  reg b = 0;      // a |-> b therefore fails on every sampled edge

  int exp_pos = 0, inf_pos = 0;   // explicit vs inferred posedge
  int exp_neg = 0, inf_neg = 0;   // explicit vs inferred negedge
  int outer   = 0, inner   = 0;   // nested event controls
  int named_c = 0, named_u = 0;   // named property, clocked vs unclocked decl

  property p_clocked;            // carries its own clock
    @(posedge clk) a |-> b;
  endproperty

  property p_unclocked;          // must take the enclosing always block's
    a |-> b;                     // clock, like a literal property would
  endproperty

  always @(posedge clk) begin assert property (p_clocked)   else named_c++; end
  always @(posedge clk) begin assert property (p_unclocked) else named_u++; end

  always @(posedge clk) assert property (@(posedge clk) a |-> b) else exp_pos++;
  always @(posedge clk) assert property (               a |-> b) else inf_pos++;

  always @(negedge clk) assert property (@(negedge clk) a |-> b) else exp_neg++;
  always @(negedge clk) assert property (               a |-> b) else inf_neg++;

  always @(posedge clk) begin
    assert property (a |-> b) else outer++;                  // outer posedge
    @(negedge clk) assert property (a |-> b) else inner++;    // inner negedge
  end

  initial begin
    #5 clk = 1;   // posedge @5
    #5 clk = 0;   // negedge @10
    #5 clk = 1;   // posedge @15
    #5 clk = 0;   // negedge @20
    #5;

    if (exp_pos == 0 || exp_neg == 0)
      $display("FAILED -- an explicitly clocked control never fired (pos=%0d neg=%0d); the test itself is broken",
               exp_pos, exp_neg);
    else if (inf_pos != exp_pos)
      $display("FAILED -- inferred posedge=%0d explicit=%0d", inf_pos, exp_pos);
    else if (inf_neg != exp_neg)
      $display("FAILED -- inferred negedge=%0d explicit=%0d; the inferred edge is not the one written",
               inf_neg, exp_neg);
    else if (outer != exp_pos)
      $display("FAILED -- nested-outer=%0d expected %0d; the assertion above the inner @ did not take the outer clock",
               outer, exp_pos);
    else if (inner != exp_neg)
      $display("FAILED -- nested-inner=%0d expected %0d; the assertion under the inner @ did not take the inner clock",
               inner, exp_neg);
    else if (named_c != exp_pos)
      $display("FAILED -- named clocked property=%0d expected %0d", named_c, exp_pos);
    else if (named_u != exp_pos)
      $display("FAILED -- named unclocked property=%0d expected %0d; it did not take the enclosing clock",
               named_u, exp_pos);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
