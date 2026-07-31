// `default disable iff' takes an expression with NO parentheses
// (IEEE 1800-2017 A.2.10):
//
//     module_or_generate_item_declaration ::= ...
//       | default disable iff expression_or_dist ;
//
// The grammar required them, so the ordinary spelling was rejected as
// "Invalid module item" -- and because that is a module-item error, the
// parser then failed to recover for the rest of the module and every
// later assertion in the file reported an error too. OpenTitan's
// tlul_assert.sv writes
//
//     default disable iff disable_sva || !rst_ni;
//
// A parenthesized expression is still an expression, so the previously
// accepted form has to keep working; both are checked here.
//
// The default applies to assertions that have no disable clause of
// their own, and must NOT override one that does. Both are exercised:
// with dis=1 the defaulted assertion is disabled and cannot fire, while
// the one carrying `disable iff (1'b0)' stays live.
module sv_default_disable_iff;

  logic clk = 0;
  logic a = 0, b = 0;
  bit   dis = 0;
  int   fired_def = 0;   // hits from the assertion that takes the default
  int   fired_exp = 0;   // hits from the one with its own disable clause
  int   errors = 0;

  always #5 clk = ~clk;

  // no parentheses -- the form that used to be rejected
  default disable iff dis || 1'b0;

  // takes the default: silent while dis is high
  A_defaulted: assert property (@(posedge clk) a |-> b)
    else fired_def = fired_def + 1;

  // carries its own disable clause: the default must not replace it
  A_explicit: assert property (@(posedge clk) disable iff (1'b0) (a |-> b))
    else fired_exp = fired_exp + 1;

  initial begin
    // With the default disable active, a violation must not be counted
    // by A_defaulted. A_explicit has its own (never true) disable, so it
    // still reports.
    dis = 1'b1;
    a = 1'b1; b = 1'b0;
    repeat (3) @(posedge clk);
    if (fired_def != 0) begin
      $display("FAIL disabled-phase: defaulted assertion fired %0d times, expected 0",
               fired_def);
      errors = errors + 1;
    end
    if (fired_exp == 0) begin
      $display("FAIL disabled-phase: explicit-disable assertion never fired -- the");
      $display("     default must not replace a clause the assertion already has");
      errors = errors + 1;
    end

    // Release the default disable: the defaulted assertion must now report.
    fired_def = 0;
    dis = 1'b0;
    repeat (3) @(posedge clk);
    if (fired_def == 0) begin
      $display("FAIL enabled-phase: defaulted assertion never fired after release");
      errors = errors + 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
    $finish;
  end

endmodule
