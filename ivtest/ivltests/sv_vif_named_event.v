// A named event declared in an interface is waited on and triggered through
// a virtual interface handle (IEEE 1800-2017/2023 25.9, 15.5.1): `@(vif.ev)'
// in a class method, `->vif.ev', `->>vif.ev', through a nested class handle,
// and mixed with direct hierarchical `@(i.ev)' / `->i.ev' on the instance.
// A `@(vif.ev)' used to be skipped with a warning, so the wait fell through
// immediately; `->vif.ev' was rejected as "not a named event" (OpenTitan chip
// sw_logger_if printed_log_event).
interface ifc;
  event ev;
  event other;
  logic [7:0] d;
endinterface

class waiter;
  virtual ifc vif;
  int woke;
  int last_d;
  task wait_ev();
    @(vif.ev);
    woke++;
    last_d = vif.d;
  endtask
  task wait_other();
    @(vif.other);
    woke += 100;
  endtask
endclass

class holder;
  waiter w;
endclass

class driver;
  virtual ifc vif;
  task fire(bit [7:0] value);
    vif.d = value;
    ->vif.ev;
  endtask
  task fire_other();
    ->vif.other;
  endtask
  task fire_nb();
    ->>vif.ev;
  endtask
endclass

module main;
  int errors;
  int direct_woke;
  ifc i();
  waiter w;
  holder h;
  driver drv;

  task automatic check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    w = new; h = new; drv = new;
    w.vif = i;
    h.w = w;
    drv.vif = i;

    // Waiter parked on the vif before the trigger; the trigger comes from the
    // module through the instance.
    fork w.wait_ev(); join_none
    #5;
    check("no early wake", w.woke, 0);
    i.d = 8'd7;
    ->i.ev;
    #1;
    check("direct trigger wakes vif waiter", w.woke, 1);
    check("data visible after wake", w.last_d, 7);

    // Trigger through a vif handle, waiter on the vif too.
    fork w.wait_ev(); join_none
    #5;
    drv.fire(8'd42);
    #1;
    check("vif trigger wakes vif waiter", w.woke, 2);
    check("data from vif trigger", w.last_d, 42);

    // Trigger through a vif handle, waiter on the instance event.
    fork begin @(i.ev); direct_woke++; end join_none
    #5;
    drv.fire(8'd9);
    #1;
    check("vif trigger wakes direct waiter", direct_woke, 1);

    // A different event must not wake an ev waiter, and a nested handle path
    // works for the wait.
    fork h.w.wait_ev(); h.w.wait_other(); join_none
    #5;
    drv.fire_other();
    #1;
    check("other event only", w.woke, 2 + 100);
    drv.fire(8'd1);
    #1;
    check("ev after other", w.woke, 3 + 100);

    // Nonblocking trigger through the handle.
    fork w.wait_ev(); join_none
    #5;
    drv.fire_nb();
    #2;
    check("nonblocking trigger", w.woke, 4 + 100);

    if (errors == 0) $display("PASSED");
  end
endmodule
