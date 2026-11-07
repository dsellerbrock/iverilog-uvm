class issue2718_item;
  rand bit b;
  rand bit [3:0] m[2][3];
  constraint implication_foreach {
    b -> foreach (m[i, j]) m[i][j] == 1;
  }
endclass

module issue2718_constraint_implication_foreach;
  initial begin
    issue2718_item item;
    item = new;
    if (!item.randomize() with { b == 1; })
      $fatal(1, "randomize failed");
    foreach (item.m[i, j])
      if (item.m[i][j] != 1)
        $fatal(1, "implication foreach constraint failed at %0d,%0d", i, j);
    $display("rc=1");
    $display("m=%0d %0d", item.m[0][0], item.m[1][2]);
  end
endmodule
