class C;
  rand bit x;
  bit q[2][2][$];
  constraint c { foreach (q[i,j]) q[i][j].size() == 1; }
endclass
module test;
  C c;
  initial begin
    c = new;
    foreach (c.q[i,j]) c.q[i][j] = '{1};
    if (!c.randomize()) $fatal(1, "valid state size rejected");
    c.q[1][1].push_back(0);
    if (c.randomize()) $fatal(1, "invalid state size accepted");
    $display("PASSED");
  end
endmodule
