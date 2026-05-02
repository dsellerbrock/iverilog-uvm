// Phase 63b/Q-methods: queue.sort/rsort/unique with iterator+with-clause
// must evaluate the predicate per element to extract a sort key.
//
// Pre-fix: the with-clause was silently dropped — sort/rsort used
// the default element compare (pointer identity for class queues,
// value compare for vec4).  The user's `q.sort with (key_extractor)`
// produced an order based on the wrong key.
//
// Real impl: decorate-sort-undecorate.  Evaluate predicate per
// element to build a parallel keys queue, then sort q by keys via a
// new runtime opcode (%qsort/keys, %qrsort/keys, %qunique/keys).
`timescale 1ns/1ps

module top;
  initial begin
    int q[$];
    int i;

    // T1: q.sort with (item) — sort by item value (same as default but
    // exercises the with-clause path)
    q.push_back(30);
    q.push_back(10);
    q.push_back(20);
    q.sort with (item);
    if (q.size() != 3 || q[0] !== 10 || q[1] !== 20 || q[2] !== 30)
      $fatal(1, "FAIL/T1: got [%0d,%0d,%0d]", q[0], q[1], q[2]);

    // T2: q.rsort with (item)
    q.rsort with (item);
    if (q[0] !== 30 || q[1] !== 20 || q[2] !== 10)
      $fatal(1, "FAIL/T2: got [%0d,%0d,%0d]", q[0], q[1], q[2]);

    // T3: q.sort with (-item) — sort descending via key negation
    while (q.size() > 0) void'(q.pop_back());
    q.push_back(5); q.push_back(15); q.push_back(8);
    q.sort with (-item);
    if (q[0] !== 15 || q[1] !== 8 || q[2] !== 5)
      $fatal(1, "FAIL/T3: got [%0d,%0d,%0d]", q[0], q[1], q[2]);

    // T4: q.unique with (item % 10) — dedup by mod 10
    while (q.size() > 0) void'(q.pop_back());
    q.push_back(3);   // key=3
    q.push_back(13);  // key=3 (dup)
    q.push_back(5);   // key=5
    q.push_back(25);  // key=5 (dup)
    q.push_back(7);   // key=7
    q.unique with (item % 10);
    // Expected: keep first of each unique key → [3, 5, 7]
    if (q.size() != 3)
      $fatal(1, "FAIL/T4: size=%0d expected 3", q.size());
    if (q[0] !== 3 || q[1] !== 5 || q[2] !== 7)
      $fatal(1, "FAIL/T4: got [%0d,%0d,%0d]", q[0], q[1], q[2]);

    $display("PASS: queue.sort/rsort/unique with predicate key extractor");
    $finish;
  end
endmodule
