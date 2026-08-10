// Queue locator methods on class-property arrays use the same live
// predicate evaluation as direct queue receivers. This older smoke remains
// an acceptance check; sv_array_find_last carries the value and result-type
// oracles, including the single-rightmost-match rule.
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
    // These should compile and evaluate their with clauses.
    found = c.q.find with (item == 20);
    idx   = c.q.find_index with (item > 15);
    found = c.q.find_first with (item == 20);
    idx   = c.q.find_first_index with (item > 15);
    $display("PASS: queue find*/find_*_index methods compile");
    $finish;
  end
endmodule
