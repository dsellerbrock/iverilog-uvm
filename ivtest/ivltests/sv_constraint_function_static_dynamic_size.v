class C;
  static rand int q[];
  rand int x;

  function int f(input int value);
    return value + 1;
  endfunction

  constraint c { q.size() == 2; x == f(q.size()); }
endclass

module test;
  C c;
  int ok;
  initial begin
    c = new;
    c.q = new[1];
    c.q[0] = 42;
    c.x = 37;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 2 || c.x !== 3)
      $fatal(1, "static size ok=%0d size=%0d x=%0d",
             ok, c.q.size(), c.x);
    $display("PASSED");
  end
endmodule
