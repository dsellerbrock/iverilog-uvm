// IEEE 1800-2017 7.10.1: `$' as the right bound of a queue slice is
// evaluated as the current last queue index. The result is a new queue
// containing every element from the left bound through that last index.
module main;
  bit failed = 0;

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  int q[$], r[$];
  string sq[$], sr[$];
  int lo;

  initial begin
    string rendered;

    q = {5, 1, 4, 9};
    lo = 1;
    r = q[lo:$];
    check("dynamic lower bound", r.size() == 3 &&
          r[0] == 1 && r[1] == 4 && r[2] == 9);

    // A slice has value semantics: changing it cannot mutate its source.
    r[0] = 88;
    check("slice copy", q[1] == 1 && r[0] == 88);

    lo = 99;
    r = q[lo:$];
    check("lower bound past last", r.size() == 0);

    sq = {"a", "b", "c"};
    sr = sq[1:$];
    check("string queue", sr.size() == 2 &&
          sr[0] == "b" && sr[1] == "c");

    rendered = $sformatf("%p", q[2:$]);
    check("expression value", rendered == "'{4, 9}");

    if (failed)
      $finish(1);
    else begin
      $display("PASSED");
      $finish(0);
    end
  end
endmodule
