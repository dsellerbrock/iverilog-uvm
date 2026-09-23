class event_box;
  event ev;
endclass

module class_event_wait_control;
  event_box a;
  event_box b;
  bit a_woke;
  bit b_woke;

  initial begin
    a = new;
    b = new;
    a_woke = 0;
    b_woke = 0;
    fork
      begin @(a.ev); a_woke = 1; end
      begin @(b.ev); b_woke = 1; end
    join_none
    #1;
    -> a.ev;
    #1;
    if (!a_woke || b_woke) $fatal(1, "per-instance event wait control failed");
    $display("CLASS_EVENT_WAIT_CONTROL_PASS");
    $finish;
  end
endmodule
