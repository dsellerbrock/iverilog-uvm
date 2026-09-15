class C;
  rand int q[];
  rand int x;
  int wanted_size;

  function int f(input int value);
    return value + 1;
  endfunction

  constraint c {
    q.size() == wanted_size;
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
    c.q = new[1];
    c.q[0] = 42;
    c.x = 37;
    c.wanted_size = 3;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 3 || c.q[0] !== 10
        || c.q[1] !== 9 || c.x !== 10)
      $fatal(1, "grow ok=%0d size=%0d q0=%0d q1=%0d x=%0d",
             ok, c.q.size(), c.q[0], c.q[1], c.x);

    c.wanted_size = 2;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 2 || c.q[0] !== 10
        || c.q[1] !== 9 || c.x !== 10)
      $fatal(1, "shrink ok=%0d size=%0d q0=%0d q1=%0d x=%0d",
             ok, c.q.size(), c.q[0], c.q[1], c.x);
    $display("PASSED");
  end
endmodule
