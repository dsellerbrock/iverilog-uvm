class S;
  rand int x;
  static constraint c { x == 5; }
endclass

module test;
  initial begin
    S a;
    S b;
    a = new;
    b = new;

    a.c.constraint_mode(0);
    if (a.c.constraint_mode() !== 0 || b.c.constraint_mode() !== 0)
      $fatal(1, "static constraint mode was not shared after disable");
    if (!b.randomize() with { x == 7; } || b.x != 7)
      $fatal(1, "disabled static constraint still constrained b");

    b.c.constraint_mode(1);
    if (a.c.constraint_mode() !== 1 || b.c.constraint_mode() !== 1)
      $fatal(1, "static constraint mode was not shared after enable");
    if (a.randomize() with { x == 7; })
      $fatal(1, "enabled static constraint did not constrain a");
    $display("PASSED");
  end
endmodule
