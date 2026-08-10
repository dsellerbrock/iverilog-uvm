// A class-scoped static queue is real signal-backed storage. Its explicit
// C::q[lo:$] l-value must use the same suffix-slice semantics as a local queue.
class queue_owner;
  static int q[$];
  static string names[$];
endclass

module main;
  bit failed;
  int rhs[$];
  string srhs[$];

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    queue_owner::q = {1, 2, 3, 4};
    rhs = {20, 30, 40};
    queue_owner::q[1:$] = rhs;
    check("scoped integral queue", queue_owner::q.size() == 4 &&
          queue_owner::q[0] == 1 && queue_owner::q[1] == 20 &&
          queue_owner::q[2] == 30 && queue_owner::q[3] == 40);

    queue_owner::names = {"keep", "a", "b"};
    srhs = {"x", "y"};
    queue_owner::names[1:$] = srhs;
    check("scoped string queue", queue_owner::names.size() == 3 &&
          queue_owner::names[0] == "keep" &&
          queue_owner::names[1] == "x" && queue_owner::names[2] == "y");

    if (failed)
      $finish(1);
    $display("PASSED");
  end
endmodule
