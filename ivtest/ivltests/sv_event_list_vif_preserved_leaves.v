// IEEE 1800-2017/2023 9.4.2: each event-expression in an event-or
// expression is an independent wake source.  A dynamically selected virtual
// interface member needs a separate cancellable waiter when it is mixed with
// a class event (15.5), an event-array element (6.17), or the clocking events
// defined by 14.10, 14.12, and 14.14.  Splitting the list must still route
// each special leaf through its complete single-leaf elaboration path.
`timescale 1ns/1ps

interface event_list_preserved_if;
  logic watched;
endinterface

class event_list_preserved_box;
  event class_source;
endclass

module sv_event_list_vif_preserved_leaves;
  event_list_preserved_if bus();
  virtual event_list_preserved_if vif;
  event_list_preserved_box box;

  event array_source[2];
  int array_index;
  logic direct_clk;
  logic default_clk;
  logic global_clk;
  int hits[7];

  clocking direct_cb @(posedge direct_clk);
  endclocking

  default clocking default_cb @(posedge default_clk);
  endclocking

  global clocking global_cb @(posedge global_clk);
  endclocking

  task automatic check_hits(input int which, input int expected,
                            input string label);
    if (hits[which] != expected)
      $fatal(1, "%s produced %0d wakes, expected %0d",
             label, hits[which], expected);
  endtask

  initial begin
    vif = bus;
    box = new;
    bus.watched = 0;
    array_index = 1;
    direct_clk = 0;
    default_clk = 0;
    global_clk = 0;

    // A class-event winner cancels the dynamic VIF loser.
    fork
      begin
        @(vif.watched or box.class_source);
        hits[0]++;
      end
    join_none
    #1 -> box.class_source;
    #1 check_hits(0, 1, "class-event winner");
    bus.watched = 1;
    #1 check_hits(0, 1, "cancelled VIF after class event");

    // A dynamic VIF winner cancels the per-object class-event loser.
    bus.watched = 0;
    #1;
    fork
      begin
        @(box.class_source or vif.watched);
        hits[1]++;
      end
    join_none
    #1 bus.watched = 1;
    #1 check_hits(1, 1, "VIF winner over class event");
    -> box.class_source;
    #1 check_hits(1, 1, "cancelled class-event loser");

    // A run-time-selected event-array element retains its element identity.
    bus.watched = 0;
    #1;
    fork
      begin
        @(vif.watched or array_source[array_index]);
        hits[2]++;
      end
    join_none
    #1 -> array_source[array_index];
    #1 check_hits(2, 1, "event-array winner");
    bus.watched = 1;
    #1 check_hits(2, 1, "cancelled VIF after event-array element");

    // A directly named clocking block remains an Observed-region clocking
    // event rather than being reduced to an ordinary expression.
    bus.watched = 0;
    #1;
    fork
      begin
        @(vif.watched or direct_cb);
        hits[3]++;
      end
    join_none
    #1 direct_clk = 1;
    #1 check_hits(3, 1, "direct clocking-block winner");
    bus.watched = 1;
    #1 check_hits(3, 1, "cancelled VIF after direct clocking event");

    // A named default clocking block is also legal as an event-control leaf.
    bus.watched = 0;
    #1;
    fork
      begin
        @(vif.watched or default_cb);
        hits[4]++;
      end
    join_none
    #1 default_clk = 1;
    #1 check_hits(4, 1, "default clocking-block winner");
    bus.watched = 1;
    #1 check_hits(4, 1, "cancelled VIF after default clocking event");

    // The global clocking event must survive the same split-list lowering.
    bus.watched = 0;
    #1;
    fork
      begin
        @(vif.watched or $global_clock);
        hits[5]++;
      end
    join_none
    #1 global_clk = 1;
    #1 check_hits(5, 1, "$global_clock winner");
    bus.watched = 1;
    #1 check_hits(5, 1, "cancelled VIF after global clocking event");

    // Conversely, a VIF winner must unlink a named clocking-block loser.
    bus.watched = 0;
    default_clk = 0;
    #1;
    fork
      begin
        @(default_cb or vif.watched);
        hits[6]++;
      end
    join_none
    #1 bus.watched = 1;
    #1 check_hits(6, 1, "VIF winner over default clocking event");
    default_clk = 1;
    #1 check_hits(6, 1, "cancelled default-clocking loser");

    $display("PASSED");
    $finish(0);
  end
endmodule
