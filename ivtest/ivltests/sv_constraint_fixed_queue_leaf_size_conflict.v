class queue_conflict;
  rand bit q[2][$];
  constraint sizes { q[0].size() == 1; q[0].size() == 2; }
endclass

module test;
  queue_conflict c;
  initial begin
    c = new;
    c.q[0] = '{1, 0, 1};
    c.q[1] = '{0};
    if (!c.randomize() && c.q[0].size() == 3 && c.q[1].size() == 1)
      $display("PASSED");
    else
      $display("FAILED -- contradictory indexed size was accepted");
  end
endmodule
