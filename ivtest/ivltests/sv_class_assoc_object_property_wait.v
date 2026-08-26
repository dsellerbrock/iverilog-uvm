// IEEE 1800-2017 9.4.3: a wait statement reevaluates its expression when an
// operand changes.  Preserve the dynamic associative key and the selected
// object while tracking the scalar property at the end of the path.
class class_assoc_wait_leaf;
  bit done;
endclass

class class_assoc_wait_config;
  class_assoc_wait_leaf map[string];
  string names[];
endclass

class class_assoc_wait_scenario;
  class_assoc_wait_config cfg;
  int index;
  bit completed;
  bit selector_completed;
  bit element_replace_completed;
  bit root_replace_completed;

  task wait_once;
    wait (cfg.map[cfg.names[index]].done == 1'b1);
    completed = 1'b1;
  endtask

  task wait_selector_change;
    wait (cfg.map[cfg.names[index]].done == 1'b1);
    selector_completed = 1'b1;
  endtask

  task wait_element_replace;
    wait (cfg.map[cfg.names[index]].done == 1'b1);
    element_replace_completed = 1'b1;
  endtask

  task wait_root_replace;
    wait (cfg.map[cfg.names[index]].done == 1'b1);
    root_replace_completed = 1'b1;
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
      wait_once();
    join_none

    #1;
    cfg.map[cfg.names[1]].done = 1'b1;
    #1;
    if (completed) begin
      $fatal(1, "another associative element satisfied wait");
    end

    cfg.map[cfg.names[index]].done = 1'b1;
    #1;
    if (!completed) begin
      $fatal(1, "selected nested property did not wake wait");
    end

    // A selector is an operand of the wait expression, not an arm-time
    // constant. Moving it to an already-true element must re-evaluate.
    cfg.map[cfg.names[0]].done = 1'b0;
    cfg.map[cfg.names[1]].done = 1'b1;
    index = 0;
    fork
      wait_selector_change();
    join_none
    #1;
    index = 1;
    #1;
    if (!selector_completed) begin
      $fatal(1, "dynamic associative selector did not wake wait");
    end

    // Replacing the selected associative element migrates the subscription
    // from the old leaf to the new one.
    begin
      class_assoc_wait_leaf replacement;
      replacement = new;
      replacement.done = 1'b1;
      index = 0;
      cfg.map[cfg.names[index]] = new;
      fork
        wait_element_replace();
      join_none
      #1;
      cfg.map[cfg.names[index]] = replacement;
      #1;
      if (!element_replace_completed) begin
        $fatal(1, "selected associative owner replacement did not wake wait");
      end
    end

    // The same rule applies when an intermediate/root handle is replaced.
    begin
      class_assoc_wait_config replacement_cfg;
      replacement_cfg = new;
      replacement_cfg.names = new[2];
      replacement_cfg.names[0] = "selected";
      replacement_cfg.names[1] = "other";
      replacement_cfg.map["selected"] = new;
      replacement_cfg.map["selected"].done = 1'b1;
      index = 0;
      cfg.map[cfg.names[index]] = new;
      fork
        wait_root_replace();
      join_none
      #1;
      cfg = replacement_cfg;
      #1;
      if (!root_replace_completed) begin
        $fatal(1, "class owner replacement did not wake wait");
      end
    end

    $display("PASSED");
  endtask
endclass

module sv_class_assoc_object_property_wait;
  class_assoc_wait_scenario scenario;

  initial begin
    scenario = new;
    scenario.run();
  end
endmodule
