// M9-10 adversarial: the unclocked assertion is NOT inside the always
// block -- the always block merely follows it. Clock inference must not
// reach across to a sibling event control, because adopting a clock the
// assertion is not lexically inside would evaluate it on edges the user
// never associated with it, silently. With nothing enclosing it, this is
// the 16.14.6 error.
module top;
  logic clk = 0, a = 1, b = 0;
  initial assert property (a |-> b);
  always @(posedge clk) b <= a;
endmodule
