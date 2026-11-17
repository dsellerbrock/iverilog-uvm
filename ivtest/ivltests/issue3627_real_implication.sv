class C;
  real w;
  rand bit b;
  constraint k {
    w -> (b == 1);
    (w + 0.0) -> (b == 1);
    (w > 0.0) -> (b == 1);
    (w -> (b == 1));
  }
endclass
class D;
  real w;
  rand bit b;
  constraint k { w -> { b == 1; } b == 0; }
endclass
module tb;
  C c;
  D d;
  initial begin
    c = new;
    c.w = 0.5;
    if (!c.randomize() || c.b != 1) $fatal(1, "true real predicate");
    if (c.randomize() with { b == 0; }) $fatal(1, "true predicate ignored");
    d = new;
    d.w = 0.0;
    if (!d.randomize() || d.b != 0) $fatal(1, "false real predicate");
    d.w = 0.5;
    if (d.randomize()) $fatal(1, "braced predicate ignored");
    $display("PASS");
  end
endmodule
