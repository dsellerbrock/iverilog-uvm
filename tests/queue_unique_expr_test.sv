// Phase 63b/Q-methods: queue.unique() expression form returns a new
// queue with duplicates removed (q itself unchanged), and
// queue.unique_index() returns one representative index per unique value.
// IEEE 1800-2017 7.12.1 does not specify result order or which duplicate
// index represents an equal-value class.
//
// Pre-fix: both expression forms returned NetENull — the size of the
// returned queue was 0 regardless of input.  Test: dedupe a queue
// with repeats and verify the result has the right size and values.
`timescale 1ns/1ps

module top;
  initial begin
    int q[$];
    int u[$];
    int idx[$];
    bit saw_1;
    bit saw_2;
    bit saw_3;
    bit saw_4;
    int i;

    q.push_back(1);
    q.push_back(2);
    q.push_back(1);
    q.push_back(3);
    q.push_back(2);
    q.push_back(3);
    q.push_back(4);

    u = q.unique();
    if (u.size() != 4)
      $fatal(1, "FAIL/T1: unique size=%0d expected 4", u.size());
    u.sort();
    if (u[0] !== 1 || u[1] !== 2 || u[2] !== 3 || u[3] !== 4)
      $fatal(1, "FAIL/T1: got [%0d,%0d,%0d,%0d]", u[0], u[1], u[2], u[3]);

    // Original q should be unchanged
    if (q.size() != 7)
      $fatal(1, "FAIL/T2: q.size()=%0d expected 7 (should be unchanged)",
             q.size());

    idx = q.unique_index();
    if (idx.size() != 4)
      $fatal(1, "FAIL/T3: unique_index size=%0d expected 4", idx.size());
    saw_1 = 0;
    saw_2 = 0;
    saw_3 = 0;
    saw_4 = 0;
    for (i = 0; i < idx.size(); i++) begin
      if (idx[i] < 0 || idx[i] >= q.size())
        $fatal(1, "FAIL/T3: out-of-range representative index %0d", idx[i]);
      case (q[idx[i]])
        1: saw_1 = 1;
        2: saw_2 = 1;
        3: saw_3 = 1;
        4: saw_4 = 1;
        default: $fatal(1, "FAIL/T3: unexpected represented value");
      endcase
    end
    if (!(saw_1 && saw_2 && saw_3 && saw_4))
      $fatal(1, "FAIL/T3: representative indexes miss a value class");

    $display("PASS: queue.unique() + queue.unique_index() expression forms");
    $finish;
  end
endmodule
