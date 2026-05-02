// Phase 63b/B1 (real impl): queue find/find_index/find_first/find_first_index
// must actually evaluate the with-clause predicate per element and
// return the matching elements (or indices).
//
// This replaces the silent-null compile-progress fallback that
// landed in commit 2566a0aec.
//
// Coverage:
//   T1-T6 : int element queues
//   T7    : real element queues
//   T8    : string element queues
//   T9    : class-handle element queues
`timescale 1ns/1ps

class my_obj;
  int data;
  function new(int d); data = d; endfunction
endclass

module top;
  initial begin
    int q[$];
    int found[$];
    int idx[$];

    q.push_back(10);
    q.push_back(25);
    q.push_back(30);
    q.push_back(7);

    // Test 1: find with simple equality
    found = q.find with (item == 25);
    if (found.size() != 1 || found[0] !== 25)
      $fatal(1, "FAIL/T1: expected [25], got size=%0d", found.size());

    // Test 2: find with greater-than
    found = q.find with (item > 15);
    if (found.size() != 2 || found[0] !== 25 || found[1] !== 30)
      $fatal(1, "FAIL/T2: expected [25,30] got size=%0d", found.size());

    // Test 3: find_index returns indices
    idx = q.find_index with (item < 20);
    if (idx.size() != 2 || idx[0] !== 0 || idx[1] !== 3)
      $fatal(1, "FAIL/T3: expected [0,3] got size=%0d", idx.size());

    // Test 4: find_first
    found = q.find_first with (item > 20);
    if (found.size() != 1 || found[0] !== 25)
      $fatal(1, "FAIL/T4: expected [25] got size=%0d", found.size());

    // Test 5: find_first_index
    idx = q.find_first_index with (item > 20);
    if (idx.size() != 1 || idx[0] !== 1)
      $fatal(1, "FAIL/T5: expected [1] got size=%0d", idx.size());

    // Test 6: empty result
    found = q.find with (item > 100);
    if (found.size() != 0)
      $fatal(1, "FAIL/T6: expected empty got size=%0d", found.size());

    // Test 7: real element queue
    begin
      real rq[$];
      real rf[$];
      rq.push_back(1.5);
      rq.push_back(2.7);
      rq.push_back(3.9);
      rf = rq.find with (item > 2.0);
      if (rf.size() != 2 || rf[0] != 2.7 || rf[1] != 3.9)
	$fatal(1, "FAIL/T7: expected [2.7,3.9] got size=%0d", rf.size());
    end

    // Test 8: string element queue
    begin
      string sq[$];
      string sf[$];
      sq.push_back("alpha");
      sq.push_back("beta");
      sq.push_back("gamma");
      sf = sq.find with (item == "beta");
      if (sf.size() != 1 || sf[0] != "beta")
	$fatal(1, "FAIL/T8: expected [beta] got size=%0d", sf.size());
    end

    // Test 9: class-handle element queue
    begin
      my_obj cq[$];
      my_obj cf[$];
      my_obj o0, o1, o2;
      o0 = new(7);
      o1 = new(42);
      o2 = new(13);
      cq.push_back(o0);
      cq.push_back(o1);
      cq.push_back(o2);
      cf = cq.find with (item.data == 42);
      if (cf.size() != 1 || cf[0] == null || cf[0].data !== 42)
	$fatal(1, "FAIL/T9: expected [obj(42)] got size=%0d", cf.size());
    end

    $display("PASS: queue find with predicate (int/real/string/class)");
    $finish;
  end
endmodule
