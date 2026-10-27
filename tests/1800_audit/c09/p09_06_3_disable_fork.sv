module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int got, killedA, gc, survB, hitA;
  task automatic wd(int id); #(id) got = id; endtask
  task get_first(); fork wd(1); wd(7); wd(13); join_any disable fork; endtask
  initial begin fork #50 survB = 1; join_none end
  initial begin : ic fork begin : nb #100 hitA = 1; end join_none end
  initial begin : A
    get_first(); chk("9.6.3.join_any_then_disable_fork", got == 1 && $time == 1);
    #20 chk("9.6.3.outstanding_killed", got == 1);
    fork begin fork #10 gc++; join_none end join_none
    #1 disable fork;
    #20 chk("9.6.3.kills_descendants_of_terminated_child", gc == 0);
    fork #10 killedA = 1; join_none
    #1 disable fork;
    #20 chk("9.6.3.only_own_children_killed", killedA == 0 && survB == 1);
    disable top.ic.nb;
    #200 chk("9.6.2.disable_by_name_kills_foreign_fork", hitA == 0);
    $display("DONE fails=%0d", fails);
  end
endmodule
