class C;
  rand int x;
  rand int q[$];
  function automatic int f(input int v); return v; endfunction
  constraint c {
    q.size() == 2;
    q[1] == 9;
    foreach (q[i]) q[i] == x;
    x == f(q[1]);
  }
endclass
module test;
  C c; int ok;
  initial begin
    c = new; c.q = '{31,42}; c.x = 37;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 2 || c.q[0] != 9 ||
        c.q[1] != 9 || c.x != 9)
      $fatal(1,"foreach lower ref ok=%0d size=%0d x=%0d",ok,c.q.size(),c.x);
    $display("PASSED");
  end
endmodule
