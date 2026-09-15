class row_reduce;
  int a[1:0][3:2][-1:1];
  rand int total;
  constraint c { total == a[1][2].sum(); }
endclass
module test;
 row_reduce h;
 initial begin
  h = new;
  foreach (h.a[i,j,k]) h.a[i][j][k] = 40 + i*10 + j + k;
  h.a[1][2][-1]=4; h.a[1][2][0]=5; h.a[1][2][1]=6;
  if (!h.randomize() || h.total!=15) $fatal(1,"selected row sum=%0d",h.total);
  h.a[1][2][0]=9;
  if (!h.randomize() || h.total!=19) $fatal(1,"refreshed row sum=%0d",h.total);
  if (h.randomize() with { total==20; }) $fatal(1,"contradiction succeeded");
  if (h.total!=19) $fatal(1,"failed solve changed total");
  $display("PASSED");
 end
endmodule
