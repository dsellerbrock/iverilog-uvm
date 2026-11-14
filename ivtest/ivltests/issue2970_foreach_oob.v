class unguarded;
  rand bit a[];
  constraint c { a.size() == 1; foreach (a[i]) a[i+1] == 1; }
endclass
class guarded;
  rand bit a[];
  constraint c { a.size() == 2; foreach (a[i]) (i < a.size()-1) -> a[i+1] == 1; }
endclass
module top;
  unguarded u;
  guarded g;
  initial begin
    u = new;
    g = new;
    if (u.randomize()) $fatal(1, "unguarded out-of-bounds access accepted");
    if (!g.randomize() || g.a.size() != 2 || g.a[1] != 1)
      $fatal(1, "guarded constraint failed");
    $display("PASS");
  end
endmodule
