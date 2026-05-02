// Phase 63b/Q-methods: queue.reverse() and queue.shuffle() must
// actually mutate the queue, not silently no-op.
//
// Pre-fix: SV mode dropped both methods — q.reverse() and
// q.shuffle() lowered to an empty NetBlock, so the queue was
// unchanged after the call.  Now wired to %qreverse and %qshuffle
// runtime opcodes that perform the operation in place.
`timescale 1ns/1ps

module top;
  initial begin
    int q[$];
    int orig[$];
    int seen[int];

    // T1: reverse [1,2,3,4,5] → [5,4,3,2,1]
    q.push_back(1);
    q.push_back(2);
    q.push_back(3);
    q.push_back(4);
    q.push_back(5);
    q.reverse();
    if (q.size() != 5) $fatal(1, "FAIL/T1: size=%0d", q.size());
    if (q[0] !== 5 || q[1] !== 4 || q[2] !== 3 || q[3] !== 2 || q[4] !== 1)
      $fatal(1, "FAIL/T1: got [%0d,%0d,%0d,%0d,%0d]", q[0], q[1], q[2], q[3], q[4]);

    // T2: shuffle [0..15] — must keep all elements (no duplicates, no losses)
    while (q.size() > 0) void'(q.pop_back());
    for (int i = 0; i < 16; i++) q.push_back(i);
    q.shuffle();
    if (q.size() != 16) $fatal(1, "FAIL/T2: size=%0d", q.size());
    foreach (q[i]) begin
      if (q[i] < 0 || q[i] >= 16)
	$fatal(1, "FAIL/T2: q[%0d]=%0d out of range", i, q[i]);
      if (seen.exists(q[i]))
	$fatal(1, "FAIL/T2: q[%0d]=%0d duplicate", i, q[i]);
      seen[q[i]] = 1;
    end
    if (seen.size() != 16) $fatal(1, "FAIL/T2: missing values");

    $display("PASS: queue.reverse() + queue.shuffle()");
    $finish;
  end
endmodule
