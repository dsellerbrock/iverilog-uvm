// A constant select on an earlier hierarchical component chooses an
// instance-array element; it is not the foreach target's array index.
module leaf;
  int bus[3:1];
  int md[1:2][7:5];
endmodule

module middle;
  leaf inner();
endmodule

class ShadowControl;
  bit maps[string];

  function automatic int local_queue_sum();
    int maps[$] = '{3, 4, 5};
    foreach (maps[i])
      local_queue_sum += maps[i];
  endfunction
endclass

module main;
  middle u[5:3]();
  middle plain();
  int local_arr[3:1];
  ShadowControl shadow;
  int sum;
  int fails;

  task check(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got=%0d want=%0d", what, got, want);
    end
  endtask

  initial begin
    shadow = new;
    foreach (local_arr[i]) local_arr[i] = i;
    foreach (plain.inner.bus[i]) plain.inner.bus[i] = 10 + i;
    foreach (u[4].inner.bus[i]) u[4].inner.bus[i] = 20 + i;
    foreach (u[3].inner.md[i,j]) u[3].inner.md[i][j] = 100*i + j;

    sum = 0;
    foreach (local_arr[i]) sum += local_arr[i];
    check("local control", sum, 6);
    sum = 0;
    foreach (plain.inner.bus[i]) sum += plain.inner.bus[i];
    check("unindexed hierarchy control", sum, 36);
    sum = 0;
    foreach (u[4].inner.bus[i]) sum += u[4].inner.bus[i];
    check("indexed instance read", sum, 66);
    sum = 0;
    foreach (u[3].inner.md[i,j]) sum += u[3].inner.md[i][j];
    check("indexed instance multidimensional target", sum, 936);

    foreach (u[4].inner.bus[i]) u[4].inner.bus[i] = 100 + i;
    check("indexed instance write [1]", u[4].inner.bus[1], 101);
    check("indexed instance write [3]", u[4].inner.bus[3], 103);
    check("local queue shadows class associative property",
          shadow.local_queue_sum(), 12);

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
