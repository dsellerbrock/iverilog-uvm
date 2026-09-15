class C;
  rand int x;
  rand int q[$];
  function automatic int f(input int v); return v+1; endfunction
  constraint c {
    q.size() == 3;
    q[1] == 9;
    foreach (q[i]) if (i == 1) q[i+1] == x;
    x == f(q[1]);
  }
endclass
module test;
  C c; int ok;
  initial begin
    c = new; c.q = '{31}; c.x = 37;
    ok = c.randomize();
    if (ok != 1 || c.q.size() != 3 || c.q[1] != 9 ||
        c.q[2] != 10 || c.x != 10)
      $fatal(1,"foreach future ref ok=%0d size=%0d x=%0d",ok,c.q.size(),c.x);
    $display("PASSED");
  end
endmodule
