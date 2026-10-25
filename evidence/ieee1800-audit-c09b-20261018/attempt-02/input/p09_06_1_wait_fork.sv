module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int done_cnt, desc_done; time t0;
  task automatic child(int d); #d done_cnt++; endtask
  task automatic desc(int d); #d desc_done++; endtask
  function void do_sequence(); fork child(8); child(9); join_none endfunction
  task do_test();
    fork
      child(3); child(4);
      fork : child5 desc(50); desc(60); join_none
    join_none
    do_sequence();
    wait fork;
  endtask
  initial begin : test
    t0 = $time; wait fork;
    chk("9.6.1.wait_fork_no_children_returns_immediately", $time == t0);
    t0 = $time;
    fork child(1); child(2); join_none
    do_test();
    $display("INFO 9.6.1.done_cnt=%0d desc_done=%0d elapsed=%0d", done_cnt, desc_done, $time - t0);
    chk("9.6.1.wait_fork_returns_at_last_immediate_child", ($time - t0) == 9);
    chk("9.6.1.wait_fork_children_done", done_cnt == 6);
    chk("9.6.1.wait_fork_excludes_descendants", desc_done == 0);
    #61 chk("9.6.1.descendants_still_ran", desc_done == 2);
    $display("DONE fails=%0d", fails);
  end
endmodule
