class sv_class_event_multi_object_box;
  event ev;
endclass

module sv_class_event_multi_object_list;
  sv_class_event_multi_object_box a, b;
  event static_ev;
  int wakes;

  task automatic wait_either;
    @(a.ev or b.ev);
    wakes++;
  endtask

  task automatic wait_same;
    @(a.ev or a.ev);
    wakes++;
  endtask

  task automatic wait_static;
    @(static_ev);
    wakes++;
  endtask

  initial begin
    a = new;
    b = new;
    fork wait_either(); join_none
    #1 -> b.ev;
    #1 if (wakes != 1) $fatal(1, "second object event did not wake once");
    fork wait_either(); join_none
    #1 -> a.ev;
    #1 if (wakes != 2) $fatal(1, "first object event did not wake once");
    fork wait_same(); join_none
    #1 -> a.ev;
    #1 if (wakes != 3) $fatal(1, "duplicate same-object event woke incorrectly");
    fork wait_static(); join_none
    #1 -> static_ev;
    #1 if (wakes != 4) $fatal(1, "static event control regressed");
    $display("PASS multi-object class event list");
  end
endmodule
