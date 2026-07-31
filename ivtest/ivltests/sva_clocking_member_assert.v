// Guard for the SVA strict-bind change: clocking-block members inside a
// concurrent assertion are rewritten to the underlying signal on a
// different path and must NOT be caught by the strictness. A named
// property that carries its own clocking event must keep working too.
//
// This does not discriminate against the pre-fix compiler -- it passes
// on both, which is the point. It pins the behaviour that the strict
// bind must not disturb.
module sva_clocking_member_assert;

  logic clk = 0, req = 0, ack = 0, a = 0, b = 0;
  int fired = 0, errors = 0;

  always #5 clk = ~clk;

  clocking cb @(posedge clk);
    input req;
    input ack;
  endclocking
  default clocking cb;

  // clocking-block members as assertion operands
  A_cb: assert property (cb.req |=> cb.ack)
        else fired = fired + 1;

  // a named property carrying its own clocking event
  property p_ab; @(posedge clk) a |-> b; endproperty
  A_named: assert property (p_ab)
        else fired = fired + 1;

  initial begin
    repeat (2) @(posedge clk);
    // violate the named property: a high, b low
    a <= 1'b1; b <= 1'b0;
    repeat (3) @(posedge clk);
    if (fired == 0) begin
      $display("FAIL: neither assertion fired; they are inert");
      errors = errors + 1;
    end
    a <= 1'b0;
    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
    $finish;
  end

endmodule
