module issue2233_static_constraint;
  class cfg;
    static int s = 7;
  endclass

  class item;
    rand int x;
    cfg h;
  endclass

  item a;

  initial begin
    a = new;
    if (!a.randomize() with { x == h.s; })
      $fatal(1, "randomize through null handle failed");
    if (a.x != 7)
      $fatal(1, "static property constraint produced %0d", a.x);
    $display("PASS: null-handle static property constraint");
  end
endmodule
