// Phase 63b/Q-methods: queue.unique() expression form returns a new
// queue with duplicates removed (q itself unchanged), and
// queue.unique_index() returns the indices of unique-first elements.
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
    if (u[0] !== 1 || u[1] !== 2 || u[2] !== 3 || u[3] !== 4)
      $fatal(1, "FAIL/T1: got [%0d,%0d,%0d,%0d]", u[0], u[1], u[2], u[3]);

    // Original q should be unchanged
    if (q.size() != 7)
      $fatal(1, "FAIL/T2: q.size()=%0d expected 7 (should be unchanged)",
             q.size());

    idx = q.unique_index();
    if (idx.size() != 4)
      $fatal(1, "FAIL/T3: unique_index size=%0d expected 4", idx.size());
    // Indices of unique-first appearances: 0 (1), 1 (2), 3 (3), 6 (4)
    if (idx[0] !== 0 || idx[1] !== 1 || idx[2] !== 3 || idx[3] !== 6)
      $fatal(1, "FAIL/T3: got [%0d,%0d,%0d,%0d]", idx[0], idx[1], idx[2], idx[3]);

    $display("PASS: queue.unique() + queue.unique_index() expression forms");
    $finish;
  end
endmodule
