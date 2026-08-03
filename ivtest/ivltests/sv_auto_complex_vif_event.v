interface activity_if;
  logic alert;
  logic ping;
endinterface

class activity_cfg;
  virtual activity_if vif;
endclass

class activity_monitor;
  activity_cfg cfg;
  bit woke;

  function new(virtual activity_if vif);
    cfg = new;
    cfg.vif = vif;
  endfunction

  task wait_for_activity;
    @(cfg.vif.ping || cfg.vif.alert);
    woke = 1;
  endtask
endclass

module sv_auto_complex_vif_event;
  activity_if vif();
  activity_monitor mon;

  initial begin
    mon = new(vif);
    fork
      mon.wait_for_activity();
    join_none

    #1;
    if (mon.woke) begin
      $display("FAILED: complex virtual-interface event did not suspend");
      $finish;
    end

    // Wake through the second member to prove every operand is registered.
    vif.alert = 1;
    #1;
    if (!mon.woke) begin
      $display("FAILED: virtual-interface member did not wake event");
      $finish;
    end

    $display("PASSED");
  end
endmodule
