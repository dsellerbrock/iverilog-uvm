// Queue slices (IEEE 1800-2017 7.10.1) and %p rendering of nested
// containers. Both used to crash: q[a:b] hit a packed part-select
// assert in elaboration, and %p on a queue-of-queues aborted the
// decimal formatter reading object elements as vectors.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  int q[$];
  int r[$];
  int qq[$][$];
  string sq[$], sr[$];

  initial begin
    string s;

    q = {5, 1, 4, 9};

    // basic slice
    r = q[1:2];
    check("slice", r.size() == 2 && r[0] == 1 && r[1] == 4);

    // clamped and empty slices
    r = q[2:99];
    check("clamp high", r.size() == 2 && r[0] == 4 && r[1] == 9);
    r = q[3:1];
    check("inverted empty", r.size() == 0);

    // slice of a string queue
    sq = {"a", "b", "c"};
    sr = sq[0:1];
    check("string slice", sr.size() == 2 && sr[1] == "b");

    // value semantics: mutating the slice leaves the source alone
    r = q[0:1];
    r[0] = 77;
    check("slice copy", q[0] == 5 && r[0] == 77);

    // %p on nested queues
    qq = {{1,2},{3}};
    s = $sformatf("%p", qq);
    check("p nested", s == "'{'{1, 2}, '{3}}");

    // %p on a slice expression
    s = $sformatf("%p", q[1:2]);
    check("p slice expr", s == "'{1, 4}");

    if (!failed) $display("PASSED");
  end
endmodule
