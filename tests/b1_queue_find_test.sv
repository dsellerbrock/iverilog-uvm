// Phase 63b / B1: queue find()/find_index()/find_first()/find_last()
// methods on class-property arrays must not hard-error during
// elaboration.  Pre-fix: those paths emitted "sorry: 'find()' ..."
// and incremented des->errors, breaking compile of any UVM code that
// referenced the methods (uvm_resource_pool uses find_index).
//
// This commit aligns them with the existing top-level queue locator
// fallback (returns NetENull → empty result at runtime) so the
// surrounding code compiles.  Real evaluation of the `with` clause
// is a separate, larger item; the warning warns once.
`timescale 1ns/1ps

class container;
  int q[$];
endclass

module top;
  initial begin
    container c = new();
    int idx[$];
    int found[$];
    c.q.push_back(10);
    c.q.push_back(20);
    c.q.push_back(30);
    // These should compile (and return empty queue per the
    // compile-progress fallback) instead of erroring.
    found = c.q.find with (item == 20);
    idx   = c.q.find_index with (item > 15);
    found = c.q.find_first with (item == 20);
    idx   = c.q.find_first_index with (item > 15);
    $display("PASS: queue find*/find_*_index methods compile");
    $finish;
  end
endmodule
