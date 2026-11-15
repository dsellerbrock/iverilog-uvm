// Issue #3319 (IEEE 1800-2023 21.2.1.6): %p prints an unpacked array as an
// assignment pattern. The elements of a multidimensional unpacked array are
// its subarrays, so it prints nested, in declared (left to right) order.
module top;
  int m [2][2] = '{'{1, 2}, '{3, 4}};
  int d [1:0][0:2];
  int c [2][2][2];
  logic [3:0] a [2][3];
  wire  [3:0] w [1:0][0:2];
  int one [0:2] = '{7, 8, 9};
  int failures = 0;
  genvar gi, gj;
  for (gi = 0; gi < 2; gi++)
    for (gj = 0; gj < 3; gj++)
      assign w[gi][gj] = gi * 3 + gj;

  task automatic check(string what, string got, string want);
    if (got != want) begin
      $display("FAILED: %s: %s, want %s", what, got, want);
      failures += 1;
    end
  endtask

  initial begin
    foreach (d[i, j]) d[i][j] = i * 10 + j;
    foreach (c[i, j, k]) c[i][j][k] = i * 100 + j * 10 + k;
    foreach (a[i, j]) a[i][j] = i * 3 + j;
    #1;
    check("m", $sformatf("%p", m), "'{'{1, 2}, '{3, 4}}");
    check("d", $sformatf("%p", d), "'{'{10, 11, 12}, '{0, 1, 2}}");
    check("c", $sformatf("%p", c),
          "'{'{'{0, 1}, '{10, 11}}, '{'{100, 101}, '{110, 111}}}");
    check("a", $sformatf("%p", a), "'{'{0, 1, 2}, '{3, 4, 5}}");
    check("w", $sformatf("%p", w), "'{'{3, 4, 5}, '{0, 1, 2}}");
    check("one", $sformatf("%p", one), "'{7, 8, 9}");
    if (failures == 0) $display("PASSED");
  end
endmodule
