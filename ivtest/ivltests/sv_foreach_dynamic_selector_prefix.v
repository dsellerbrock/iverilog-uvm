// foreach (a[i][j]) where `i' is an existing variable selects one element of a
// dynamic array, queue or fixed array of them and iterates it (IEEE
// 1800-2017/2023 12.7.3). It was rejected for variables ("Array a[i] needs 1
// indices to select, but only has 0 dimensions") although class properties
// and fixed arrays worked.
class holder;
  int a[][];
endclass

module main;
  int errors;
  int d[][];
  int q[$][$];
  int fd[2][];
  holder h;
  int total;

  task automatic expect_int(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    // Dynamic array of dynamic arrays: row i has i + 2 elements.
    d = new[3];
    for (int i = 0; i < 3; i++) begin
      d[i] = new[i + 2];
      foreach (d[i][j]) d[i][j] = 10 * i + j;
    end
    total = 0;
    for (int i = 0; i < 3; i++) foreach (d[i][j]) total += d[i][j];
    expect_int("darray rows", total, (0 + 1) + (10 + 11 + 12) + (20 + 21 + 22 + 23));

    // Only one row selected by a constant.
    total = 0;
    foreach (d[1][j]) total++;
    expect_int("constant row", total, 3);

    // Queue of queues.
    q = '{'{1, 2}, '{3}};
    total = 0;
    for (int i = 0; i < 2; i++) foreach (q[i][j]) total += q[i][j];
    expect_int("queue of queues", total, 6);

    // Fixed array of dynamic arrays.
    fd[0] = new[2];
    fd[1] = new[3];
    total = 0;
    for (int i = 0; i < 2; i++) foreach (fd[i][j]) total++;
    expect_int("fixed of dynamic", total, 5);

    // Class property.
    h = new;
    h.a = new[2];
    h.a[0] = new[2];
    h.a[1] = new[1];
    total = 0;
    for (int i = 0; i < 2; i++) foreach (h.a[i][j]) total++;
    expect_int("class property", total, 3);

    if (errors == 0) $display("PASSED");
  end
endmodule
