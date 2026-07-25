// M9-9: a checker instantiated INSIDE another checker (IEEE 1800-2017 17.3).
//
// The ROADMAP listed "nested-checker instantiation" among M9-9's loud
// residuals, citing tests/negative/m14_checker_unsupported. That negative
// test is about something else: a checker DECLARED inside a module, which is
// the nested-module scoping limit and is still correctly rejected. A checker
// instantiated inside another checker works, and this pins it so the claim
// cannot be re-invented and the path cannot silently regress.
//
// A parse-only test would pass while the inner checker sat inert, so the
// inner assertion is made to FAIL and the count is compared against a direct
// instantiation of the same checker driven by the same stimulus. If nesting
// were inert, `nested' would stay 0 while `direct' counted.
checker leaf(input logic c, logic x, int which);
  a_leaf: assert property (@(posedge c) x)
          else begin
            if (which == 0) main.direct_fails++;
            else            main.nested_fails++;
          end
endchecker

checker wrapper(input logic c, logic x);
  leaf inner(c, x, 1);          // checker instantiated inside a checker
endchecker

module main;

  reg clk = 0;
  reg ok  = 0;      // 0 so the inner assertion must fail on every edge

  int direct_fails = 0;
  int nested_fails = 0;

  leaf    u_direct(clk, ok, 0);   // control: same checker, same stimulus
  wrapper u_nested(clk, ok);

  initial begin
    #5  clk = 1;
    #5  clk = 0;
    #5  clk = 1;
    #5  clk = 0;
    #5;

    if (direct_fails == 0) begin
      $display("FAILED -- direct instantiation never fired (%0d); the test itself is broken",
               direct_fails);
    end
    else if (nested_fails != direct_fails) begin
      $display("FAILED -- nested=%0d direct=%0d; a checker inside a checker is not running",
               nested_fails, direct_fails);
    end
    else begin
      $display("PASSED");
    end
    $finish(0);
  end

endmodule
