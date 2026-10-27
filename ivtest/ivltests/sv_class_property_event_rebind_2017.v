module sv_class_property_event_rebind;
  class packet;
    int status;
  endclass

  packet p, q, old;
  int handle_events, member_events, member_time;

  initial begin
    p = new;
    q = new;
    old = p;
    fork
      begin @p; handle_events++; end
      begin @(p.status); member_events++; member_time = $time; end
      begin #10 p = q; end
    join_none

    #15 old.status = 7;
    #1 if (member_events != 0)
      $fatal(1, "old object woke member event at %0d", member_time);
    #4 q.status = 9;
    #1 if (handle_events != 1 || member_events != 1 || member_time != 20)
      $fatal(1, "events handle=%0d member=%0d time=%0d",
             handle_events, member_events, member_time);
    $display("PASS class-property-event-rebind");
    $finish;
  end
endmodule
