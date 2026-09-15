class C;
  rand int q[];
  rand int x;

  function int f(const ref int value);
    return value + 1;
  endfunction

  constraint c {
    q.size() == 2;
    q[1] == 9;
    x == f(q[1]);
    q[0] == x;
  }
endclass

module test;
  C c;
  int ok;
  initial begin
    c = new;
    c.q = new[3];
    c.q[0] = 31;
    c.q[1] = 42;
    c.q[2] = 53;
    c.x = 37;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 2 || c.q[0] !== 10
        || c.q[1] !== 9 || c.x !== 10)
      $fatal(1, "solve ok=%0d size=%0d q0=%0d q1=%0d x=%0d",
             ok, c.q.size(), c.q[0], c.q[1], c.x);

    c.q = new[3];
    c.q[0] = 31;
    c.q[1] = 42;
    c.q[2] = 53;
    c.x = 37;
    ok = c.randomize() with { x == 99; };
    if (ok != 0 || c.q.size() != 3 || c.q[0] !== 31
        || c.q[1] !== 42 || c.q[2] !== 53 || c.x !== 37)
      $fatal(1, "rollback ok=%0d size=%0d q0=%0d q1=%0d q2=%0d x=%0d",
             ok, c.q.size(), c.q[0], c.q[1], c.q[2], c.x);
    $display("PASSED");
  end
endmodule
