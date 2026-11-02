class cfg;
  static int s = 7;
endclass

class item;
  rand int x;
  cfg h;
endclass

module main;
  item a = new;
  int ok;
  initial begin
    ok = a.randomize() with { x == h.s; };
    $display("%0d %0d", ok, a.x);
  end
endmodule
