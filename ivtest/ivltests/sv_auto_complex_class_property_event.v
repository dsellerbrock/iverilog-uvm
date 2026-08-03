class event_cfg;
  bit active_ping;
  bit under_ping_handshake;
  bit under_ping_handshake_ph_2;
endclass

class event_monitor;
  event_cfg cfg;
  bit active_alert;
  bit woke;

  function new;
    cfg = new;
  endfunction

  task wait_for_activity;
    @({active_alert,
       cfg.active_ping,
       cfg.under_ping_handshake || cfg.under_ping_handshake_ph_2});
    woke = 1;
  endtask
endclass

module sv_auto_complex_class_property_event;
  event_monitor mon;

  initial begin
    mon = new;
    fork
      mon.wait_for_activity();
    join_none

    #1;
    if (mon.woke) begin
      $display("FAILED: complex class-property event did not suspend");
      $finish;
    end

    mon.cfg.under_ping_handshake_ph_2 = 1;
    #1;
    if (!mon.woke) begin
      $display("FAILED: nested class-property change did not wake event");
      $finish;
    end

    $display("PASSED");
  end
endmodule
