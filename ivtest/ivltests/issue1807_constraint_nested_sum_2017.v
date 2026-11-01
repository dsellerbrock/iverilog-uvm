class M;
  rand int g[2][2];
  rand int t;
  constraint c {
    foreach (g[i, j]) g[i][j] == i * 2 + j;
    t == g.sum(row) with (row.sum());
  }
endclass

module top;
  M m;
  initial begin
    m = new;
    $display("%0d %0d", m.randomize(), m.t);
  end
endmodule
