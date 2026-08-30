// IEEE 1800-2017/2023 9.4.2: every expression in an explicit event-or list
// is an independent wake source. A dynamically selected class-property leaf
// keeps its own value-change filter while an ordinary sibling remains armed.
class mixed_event_value_cfg;
  bit sck_on;
  bit left;
  bit right;
endclass

module sv_class_property_mixed_event_value_change;
  mixed_event_value_cfg cfg;
  bit sck_pulses;
  int wake_count;
  bit detached_done;

  initial begin
    cfg = new;

    // OpenTitan form, comma spelling. The ordinary source wins. Its
    // cancellation must unlink the class-property loser without killing a
    // detached child that belongs to the waiting process.
    cfg.sck_on = 0;
    sck_pulses = 0;
    wake_count = 0;
    detached_done = 0;
    fork
      begin
        fork
          begin
            #6 detached_done = 1;
          end
        join_none
        @(cfg.sck_on, sck_pulses);
        wake_count++;
      end
    join_none

    #1 cfg.sck_on = 0;
    #1;
    if (wake_count != 0)
      $fatal(1, "same-value class-property write woke comma list");

    sck_pulses = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "ordinary comma-list source did not wake exactly once");

    cfg.sck_on = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "cancelled class-property loser remained linked");

    #3;
    if (!detached_done)
      $fatal(1, "mixed-list loser cancellation killed detached child");

    // `or' spelling. The compound property source wins only when the value
    // of the complete expression changes. A same-value write and a masked
    // leaf mutation must leave the ordinary sibling armed.
    cfg.left = 0;
    cfg.right = 0;
    sck_pulses = 0;
    wake_count = 0;
    fork
      begin
        @(cfg.left && cfg.right or sck_pulses);
        wake_count++;
      end
    join_none

    #1 cfg.left = 1;
    #1;
    if (wake_count != 0)
      $fatal(1, "masked compound-property mutation woke or list");

    cfg.left = 1;
    #1;
    if (wake_count != 0)
      $fatal(1, "same-value compound-property write woke or list");

    cfg.right = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "compound class-property source did not wake exactly once");

    sck_pulses = 1;
    #1;
    if (wake_count != 1)
      $fatal(1, "cancelled ordinary loser woke after property winner");

    $display("PASSED");
  end
endmodule
