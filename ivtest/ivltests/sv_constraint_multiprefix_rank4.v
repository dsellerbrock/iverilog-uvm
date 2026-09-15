class rank4_reductions;
  rand bit [15:0] b[4:3][-2:-1][7:6][10:12];
  rand int unsigned total;
  bit fail;

  constraint selected_row_c {
    b[3][-1][6][10] == 16'h0101;
    b[3][-1][6][11] == 16'h0003;
    b[3][-1][6][12] == 16'h0004;
    b[3][-1][6].sum() == 16'h0108;
    b[3][-1][6].product() == 16'h0c0c;
    b[3][-1][6].and() == 16'h0000;
    b[3][-1][6].or() == 16'h0107;
    b[3][-1][6].xor() == 16'h0106;
    b[3][-1][6].sum(k) with (16'(k) + 16'(k.index())) == 16'h0129;
    total == b[3][-1][6].sum();
    fail -> total == 32'hdeadbeef;
  }
endclass

module test;
  rank4_reductions h;
  int ok;
  initial begin
    h = new;
    foreach (h.b[i,j,k,l]) h.b[i][j][k][l] = 16'h5a5a;
    h.b.rand_mode(0);
    h.b[3][-1][6].rand_mode(1);
    h.total = 77;
    ok = h.randomize();
    if (ok != 1 || h.total != 16'h0108
        || h.b[3][-1][6][10] != 16'h0101
        || h.b[3][-1][6][11] != 16'h0003
        || h.b[3][-1][6][12] != 16'h0004)
      $fatal(1, "rank4 selected row");
    if (h.b[4][-2][7][10] != 16'h5a5a
        || h.b[3][-2][6][12] != 16'h5a5a
        || h.b[4][-1][6][11] != 16'h5a5a)
      $fatal(1, "rank4 inactive neighboring leaves changed");
    h.fail = 1; h.total = 91;
    ok = h.randomize();
    if (ok != 0 || h.total != 91
        || h.b[3][-1][6][10] != 16'h0101)
      $fatal(1, "rank4 failed solve rollback ok=%0d total=%0d", ok, h.total);
    $display("PASSED");
  end
endmodule
