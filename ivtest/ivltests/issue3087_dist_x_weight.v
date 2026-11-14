class C;
  rand bit p;
  rand bit [7:0] q[$];
  logic [7:0] w;
  constraint c { q.size() == 1; p dist {0 :/ (w + q.size()), 1 :/ 1}; }
endclass
class guarded;
  rand bit p;
  rand bit [7:0] q[$];
  logic [7:0] w = 'x;
  bit enabled;
  constraint c {
    q.size() == 1;
    if (enabled) p dist {0 :/ (w + q.size()), 1 :/ 1};
    else p == 1;
  }
endclass
module top;
  C c;
  guarded g;
  initial begin
    c = new;
    c.p = 1;
    c.w = 'x;
    if (c.randomize() || c.p != 1 || c.q.size() != 0)
      $fatal(1, "X weight accepted or values changed");
    c.w = 'z;
    if (c.randomize() || c.p != 1 || c.q.size() != 0)
      $fatal(1, "Z weight accepted or values changed");
    g = new;
    if (!g.randomize() || g.p != 1 || g.q.size() != 1)
      $fatal(1, "inactive weight failed");
    $display("PASSED");
  end
endmodule
