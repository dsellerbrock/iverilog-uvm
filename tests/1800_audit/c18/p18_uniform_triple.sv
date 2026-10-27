class H;
  rand bit [7:0] a, b, c;
  constraint k { a < b; b < c; }
endclass

module p18_uniform_triple;
  H h;
  int n = 2000;
  real sa = 0, sb = 0, sc = 0;
  int lo = 0;
  initial begin
    h = new;
    repeat (n) begin
      void'(h.randomize());
      sa += h.a;
      sb += h.b;
      sc += h.c;
      if (h.a < 32) lo++;
    end
    $display("U %0.2f %0.2f %0.2f %0d", sa/n, sb/n, sc/n, lo);
  end
endmodule
