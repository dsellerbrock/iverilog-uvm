// M12B-cb: a plain boolean assertion reports cbAssertionSuccess when the
// sampled value is true and cbAssertionFailure when false. Drive a known
// pattern (1 1 0 1 0) -> 3 successes, 2 failures.
module top;
  logic clk = 0, sig = 1;
  int nf = 0;
  always #5 clk = ~clk;

  // else counts failures (and suppresses the default $error) — the
  // cbAssertionFailure callback still fires alongside the else action.
  a1: assert property (@(posedge clk) sig) else nf++;

  initial #1 $setup_assert_cb;   // register callbacks after registration

  initial begin
    sig=1; @(posedge clk); #1;   // success
    sig=1; @(posedge clk); #1;   // success
    sig=0; @(posedge clk); #1;   // failure
    sig=1; @(posedge clk); #1;   // success
    sig=0; @(posedge clk); #1;   // failure
    #2 $check_assert_cb(3, 2);
    $finish;
  end
endmodule
