class issue1796_dynamic_locator_count_class;
  rand int q[];
  rand int n;
  constraint c {
    q.size() == 2;
    foreach (q[i]) q[i] == i;
    n == (q.find(e) with (e > 0)).size();
  }
endclass

module test;
  issue1796_dynamic_locator_count_class d;
  int ok;
  initial begin
    d = new;
    ok = d.randomize();
    if (ok != 1 || d.q.size() != 2 || d.q[0] != 0 || d.q[1] != 1 || d.n != 1)
      $fatal(1, "dynamic locator count ok=%0d size=%0d q0=%0d q1=%0d n=%0d",
        ok, d.q.size(), d.q[0], d.q[1], d.n);
    $display("ISSUE1796_DYNAMIC_LOCATOR_COUNT_PASS");
  end
endmodule
