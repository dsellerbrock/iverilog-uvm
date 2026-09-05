// IEEE 1800-2017/2023 12.7.3 and 23.7: the prefix selects a data object;
// only the terminal bracket declares foreach loop variables. Iterating
// both arrays requires two foreach statements.
typedef struct { int v[3]; } holder_t;

module main;
  holder_t h[2];
  int errors = 0;
  int seen[2][3];

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    h[0].v = '{5, 9, 20};
    h[1].v = '{1, 2, 3};

    foreach (h[k])
      foreach (h[k].v[i]) seen[k][i] = h[k].v[i];

    check("h[0].v[0]", seen[0][0], 5);
    check("h[0].v[1]", seen[0][1], 9);
    check("h[0].v[2]", seen[0][2], 20);
    check("h[1].v[0]", seen[1][0], 1);
    check("h[1].v[1]", seen[1][1], 2);
    check("h[1].v[2]", seen[1][2], 3);

    begin
      int k, i, visits;
      k = 1;
      i = 77;
      visits = 0;
      seen[0] = '{-1, -1, -1};
      foreach (h[k].v[i]) begin
        visits++;
        seen[k][i] = h[k].v[i];
      end
      check("selected member visits", visits, 3);
      check("prefix k unchanged", k, 1);
      check("terminal loop variable shadows outer i", i, 77);
      check("unselected h[0].v[0] untouched", seen[0][0], -1);
      check("unselected h[0].v[1] untouched", seen[0][1], -1);
      check("unselected h[0].v[2] untouched", seen[0][2], -1);
    end

    if (errors) $fatal(1, "%0d checks failed", errors);
    $display("PASSED");
  end
endmodule
