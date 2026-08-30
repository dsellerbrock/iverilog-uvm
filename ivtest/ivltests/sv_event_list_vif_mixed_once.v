// IEEE 1800-2017/2023 9.4.2: each leaf of an event-or list is an
// independent one-shot wake source. Dynamically selected virtual-interface
// leaves need independent cancellation when mixed with ordinary or named
// events, while homogeneous ordinary and VIF lists remain valid.
interface event_list_vif_mixed_if;
  logic first;
  logic second;
endinterface

module sv_event_list_vif_mixed_once;
  event_list_vif_mixed_if bus();
  virtual event_list_vif_mixed_if vif;
  event named_source;
  bit ordinary;
  int wake_count;

  initial begin
    vif = bus;
    bus.first = 0;
    bus.second = 0;
    ordinary = 0;

    // The ordinary branch wins; cancelling the VIF loser must unlink it.
    wake_count = 0;
    fork
      begin
        @(vif.first or ordinary);
        wake_count++;
      end
    join_none
    #1 ordinary = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "ordinary source did not wake VIF mixture exactly once");
    bus.first = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "cancelled VIF loser remained armed");

    // The VIF branch wins; cancelling the ordinary loser must unlink it.
    wake_count = 0;
    fork
      begin
        @(vif.second, ordinary);
        wake_count++;
      end
    join_none
    #1 bus.second = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "VIF source did not wake ordinary mixture exactly once");
    ordinary = 0;
    #1;
    if (wake_count != 1)
      $fatal(1, "cancelled ordinary loser remained armed");

    // A named event is a separate waiter family from a dynamic VIF edge.
    wake_count = 0;
    fork
      begin
        @(vif.first or named_source);
        wake_count++;
      end
    join_none
    #1 -> named_source;
    #1;
    if (wake_count != 1)
      $fatal(1, "named source did not wake VIF mixture exactly once");
    bus.first = 0;
    #1;
    if (wake_count != 1)
      $fatal(1, "named winner did not cancel VIF loser");

    // Both sources change in one time slot. join_any admits the statement
    // once and cancellation prevents either registration from surviving.
    ordinary = 0;
    wake_count = 0;
    fork
      begin
        @(vif.first or ordinary);
        wake_count++;
      end
    join_none
    #1 begin
      bus.first = 1;
      ordinary = 1;
    end
    #1;
    if (wake_count != 1)
      $fatal(1, "simultaneous VIF/ordinary sources resumed %0d times",
             wake_count);
    bus.first = 0;
    ordinary = 0;
    #1;
    if (wake_count != 1)
      $fatal(1, "simultaneous-source wait left a registration armed");

    // Homogeneous VIF lists retain the established shared-wait lowering.
    wake_count = 0;
    fork
      begin
        @(vif.first or vif.second);
        wake_count++;
      end
    join_none
    #1 bus.second = 0;
    #1;
    if (wake_count != 1)
      $fatal(1, "homogeneous VIF list did not wake exactly once");
    bus.first = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "homogeneous VIF list retained a completed wait");

    // Homogeneous ordinary lists retain the compact shared NetEvWait path.
    wake_count = 0;
    fork
      begin
        @(ordinary or bus.second);
        wake_count++;
      end
    join_none
    #1 ordinary = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "homogeneous ordinary list did not wake exactly once");

    $display("PASSED");
    $finish(0);
  end
endmodule
