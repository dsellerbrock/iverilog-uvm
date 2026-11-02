module top;
  class cfg;
    int v = 5;
  endclass

  class item;
    rand int x;
    rand bit b;
    cfg h;
  endclass

  item a = new;
  int ok;

  initial begin
    ok = a.randomize() with { b -> x == h.v; x == 13; };
    if (!ok || a.x != 13 || a.b != 0) $fatal(1, "implication failed");
    $display("%0d %0d %0d", ok, a.x, a.b);

    ok = a.randomize() with { !b || x == h.v; x == 14; };
    if (!ok || a.x != 14 || a.b != 0) $fatal(1, "logical or failed");
    $display("%0d %0d %0d", ok, a.x, a.b);
  end
endmodule
