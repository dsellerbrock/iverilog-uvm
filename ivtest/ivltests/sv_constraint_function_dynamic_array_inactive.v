class C;
  rand int q[];
  rand int x;

  function int f(const ref int value);
    return value + 1;
  endfunction

  constraint c { q[1] == 9; x == f(q[1]); }
endclass

module test;
  C c;
  int ok;
  initial begin
    c = new;
    c.q = new[2];
    c.q[0] = 5;
    c.q[1] = 9;
    c.x = 37;
    c.q.rand_mode(0);
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 2 || c.q[0] !== 5
        || c.q[1] !== 9 || c.x !== 10)
      $fatal(1, "inactive ok=%0d size=%0d q0=%0d q1=%0d x=%0d",
             ok, c.q.size(), c.q[0], c.q[1], c.x);
    $display("PASSED");
  end
endmodule
