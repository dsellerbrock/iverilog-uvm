// Regression: `d = new [n](q)` initializing a dynamic array from a
// queue crashed vvp ("Assertion `that' failed" in
// vvp_darray_atom::shallow_copy) when the source was a queue -- the
// fork allocates queue objects eagerly, so even an EMPTY queue arrives
// at shallow_copy as a real object (upstream relies on its lazy-nil
// queues never getting there), and a queue is never the same concrete
// class as the target array. shallow_copy now falls back to
// element-wise copy through the virtual get/set interface
// (vendored ivtest sv_darray_copy_empty4).
module darray_copy_from_queue_test;
  initial begin
    int d[];
    int q[$];
    string sd[];
    string sq[$];
    d = new [2](q);            // empty queue source
    q.push_back(7); q.push_back(8); q.push_back(9);
    d = new [4](q);            // non-empty queue source, padded
    sq.push_back("ab");
    sd = new [2](sq);          // string flavor
    if (d.size() == 4 && d[0] == 7 && d[1] == 8 && d[2] == 9 && d[3] == 0
        && sd.size() == 2 && sd[0] == "ab" && sd[1] == "")
      $display("PASS: new[n](queue) initialization");
    else
      $display("FAIL: d=%p sd=%p", d, sd);
    $finish;
  end
endmodule
