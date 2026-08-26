// IEEE 1800-2017 9.4.2.1: an event expression triggers only when its selected
// value changes.  The selected value here is reached through a runtime
// associative key and an object stored in the associative array.
class class_assoc_event_leaf;
  bit done;
  bit unrelated;
endclass

class class_assoc_event_config;
  class_assoc_event_leaf map[string];
  string names[];
endclass

class class_assoc_event_scenario;
  class_assoc_event_config cfg;
  int index;
  int wake_count;

  task watch_once;
    @(cfg.map[cfg.names[index]].done);
    wake_count++;
  endtask

  task run;
    cfg = new;
    cfg.names = new[2];
    cfg.names[0] = "selected";
    cfg.names[1] = "other";
    index = 0;
    cfg.map[cfg.names[0]] = new;
    cfg.map[cfg.names[1]] = new;

    fork
      watch_once();
    join_none

    #1;
    cfg.map[cfg.names[1]].done = 1'b1;
    cfg.map[cfg.names[index]].unrelated = 1'b1;
    cfg.map[cfg.names[index]].done = cfg.map[cfg.names[index]].done;
    #1;
    if (wake_count != 0) begin
      $fatal(1, "unselected/same-value write woke nested event");
    end

    cfg.map[cfg.names[index]].done = 1'b1;
    #1;
    if (wake_count != 1) begin
      $fatal(1, "selected nested value change produced %0d wakes",
             wake_count);
    end

    // The dynamic key/index is part of the event expression. Selecting an
    // already-true element is itself a value change from 0 to 1.
    cfg.map[cfg.names[0]].done = 1'b0;
    cfg.map[cfg.names[1]].done = 1'b1;
    index = 0;
    fork
      watch_once();
    join_none
    #1;
    index = 1;
    #1;
    if (wake_count != 2) begin
      $fatal(1, "dynamic selector change produced %0d wakes", wake_count);
    end

    // Replacing a selected container element must migrate the one-shot
    // subscription and fire only if the complete selected value changes.
    begin
      class_assoc_event_leaf replacement;
      replacement = new;
      replacement.done = 1'b1;
      index = 0;
      cfg.map[cfg.names[index]] = new;
      fork
        watch_once();
      join_none
      #1;
      cfg.map[cfg.names[index]] = replacement;
      #1;
      if (wake_count != 3) begin
        $fatal(1, "selected owner replacement produced %0d wakes", wake_count);
      end
    end

    // Replacing an intermediate class handle follows the same value-change
    // rule and re-evaluates the complete expression on the new chain.
    begin
      class_assoc_event_config replacement_cfg;
      replacement_cfg = new;
      replacement_cfg.names = new[2];
      replacement_cfg.names[0] = "selected";
      replacement_cfg.names[1] = "other";
      replacement_cfg.map["selected"] = new;
      replacement_cfg.map["selected"].done = 1'b1;
      index = 0;
      cfg.map[cfg.names[index]] = new;
      fork
        watch_once();
      join_none
      #1;
      cfg = replacement_cfg;
      #1;
      if (wake_count != 4) begin
        $fatal(1, "class owner replacement produced %0d wakes", wake_count);
      end
    end

    $display("PASSED");
  endtask
endclass

module sv_class_assoc_object_property_event;
  class_assoc_event_scenario scenario;

  initial begin
    scenario = new;
    scenario.run();
  end
endmodule
