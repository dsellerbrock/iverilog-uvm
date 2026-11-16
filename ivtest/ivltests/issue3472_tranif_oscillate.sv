// IEEE 1800 28.8 does not forbid a tranif whose control is a net it connects.
// Here the weak 1 enables the switch, the stronger 0 then disables it, and the
// weak 1 returns: there is no fixed point. A simulator must not hang; vvp stops
// after the settle limit with a named run-time error.
module top;
  logic d = 0, e = 1;
  wire a, b;
  assign (pull0, pull1) a = d;
  assign (weak0, weak1) b = e;
  tranif1 g (a, b, b);
  initial begin
    #1 $display("a=%v b=%v", a, b);
    $finish;
  end
endmodule
