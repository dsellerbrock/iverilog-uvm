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
//
// Coverage: T1-T4 vec4 iter, T5 real iter, T6 string iter,
// T7 class-handle iter (sort by class field).
`timescale 1ns/1ps

class my_obj;
  int priority_val;
  string name;
  function new(int p, string n); priority_val = p; name = n; endfunction
endclass

module top;
  initial begin
    int q[$];

    // T1: q.sort with (item) — sort by item value
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
    q.push_back(3);
    q.push_back(13);
    q.push_back(5);
    q.push_back(25);
    q.push_back(7);
    q.unique with (item % 10);
    if (q.size() != 3)
      $fatal(1, "FAIL/T4: size=%0d expected 3", q.size());
    if (q[0] !== 3 || q[1] !== 5 || q[2] !== 7)
      $fatal(1, "FAIL/T4: got [%0d,%0d,%0d]", q[0], q[1], q[2]);

    // T5: real iter — sort real queue by key extracted from real value
    begin
      real rq[$];
      rq.push_back(2.5);
      rq.push_back(0.7);
      rq.push_back(1.1);
      // Use floor as int key (truncate)
      rq.sort with (int'(item));
      if (rq.size() != 3 || rq[0] != 0.7 || rq[1] != 1.1 || rq[2] != 2.5)
	$fatal(1, "FAIL/T5: got [%g,%g,%g]", rq[0], rq[1], rq[2]);
    end

    // T6: string iter — sort by length (a hashable int key)
    begin
      string sq[$];
      sq.push_back("alpha");      // len 5
      sq.push_back("hi");          // len 2
      sq.push_back("xyzzy");       // len 5
      sq.push_back("longerthing"); // len 11
      sq.sort with (item.len());
      // Sorted by length ascending: "hi", "alpha"|"xyzzy", "longerthing"
      // (alpha and xyzzy both len 5; relative order may vary — just check
      // first and last positions)
      if (sq[0] != "hi" || sq[3] != "longerthing")
	$fatal(1, "FAIL/T6: got [%s,%s,%s,%s]", sq[0], sq[1], sq[2], sq[3]);
    end

    // T7: class iter — sort by .priority_val field
    begin
      my_obj cq[$];
      my_obj o1 = new(50, "A");
      my_obj o2 = new(10, "B");
      my_obj o3 = new(30, "C");
      cq.push_back(o1);
      cq.push_back(o2);
      cq.push_back(o3);
      cq.sort with (item.priority_val);
      if (cq.size() != 3) $fatal(1, "FAIL/T7: size=%0d", cq.size());
      if (cq[0].priority_val !== 10 || cq[1].priority_val !== 30 || cq[2].priority_val !== 50)
	$fatal(1, "FAIL/T7: got priorities [%0d,%0d,%0d]",
	       cq[0].priority_val, cq[1].priority_val, cq[2].priority_val);
      // Verify object identity preserved (not just key)
      if (cq[1].name != "C")
	$fatal(1, "FAIL/T7: cq[1].name=%s expected C", cq[1].name);
    end

    $display("PASS: queue.sort/rsort/unique with predicate (vec4/real/string/class iter)");
    $finish;
  end
endmodule
