// A source fanout caches its successor before invoking a relay. The second
// waiter is armed first, so the selector-killing waiter is its predecessor.
interface cached_successor_process_kill_if;
  logic [1:0] csb;
endinterface

class cached_successor_process_kill_cfg;
  virtual cached_successor_process_kill_if vif;
endclass

module cached_successor_process_kill;
  cached_successor_process_kill_if bus();
  cached_successor_process_kill_cfg cfg;
  process victim;
  event victim_armed;
  int selector_calls, survivor_woke, victim_woke, killer_woke;

  function automatic int select_and_kill();
    selector_calls++;
    if (selector_calls == 2)
      victim.kill();
    return 0;
  endfunction

  initial begin
    bus.csb = 0;
    cfg = new;
    cfg.vif = bus;

    fork : survivor_branch
      begin
        @(posedge cfg.vif.csb[0]);
        survivor_woke++;
      end
    join_none

    fork : victim_branch
      begin
        victim = process::self();
        -> victim_armed;
        @(posedge cfg.vif.csb[0]);
        victim_woke++;
      end
    join_none

    @victim_armed;
    fork : killer_branch
      begin
        // The first recipe call arms this waiter; the second kills victim.
        @(posedge cfg.vif.csb[select_and_kill()]);
        killer_woke++;
      end
    join_none

    #1 bus.csb = 1;
    #1 begin
      if (victim.status() != process::KILLED || victim_woke != 0
          || killer_woke != 1 || survivor_woke != 1)
        $fatal(1, "cached successor cancellation failed: status=%0d survivor=%0d victim=%0d killer=%0d",
               victim.status(), survivor_woke, victim_woke, killer_woke);
      $display("PASS cached successor process kill");
      $finish;
    end
  end
endmodule
