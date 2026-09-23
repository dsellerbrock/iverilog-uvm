class event_box;
  event ev;
endclass

module multi_object_event_control;
  event_box a, b;
  bit woke;

  initial begin
    a = new;
    b = new;
    fork begin
      @(a.ev or b.ev);
      woke = 1;
    end join_none
    #1;
    -> b.ev;
    #1;
    if (!woke) $fatal(1, "b event did not wake mixed object event control");
    $display("MULTI_OBJECT_EVENT_CONTROL_PASS");
    $finish;
  end
endmodule
