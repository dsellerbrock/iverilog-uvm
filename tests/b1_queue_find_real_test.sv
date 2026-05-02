// Phase 63b/B1 (real impl): queue find/find_index/find_first/find_first_index
// must actually evaluate the with-clause predicate per element and
// return the matching elements (or indices).
//
// This replaces the silent-null compile-progress fallback that
// landed in commit 2566a0aec.
`timescale 1ns/1ps

module top;
  initial begin
    int q[$];
    int found[$];
    int idx[$];
    int n;

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

    $display("PASS: queue find/find_index/find_first* with predicate");
    $finish;
  end
endmodule
