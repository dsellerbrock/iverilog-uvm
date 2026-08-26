// wait(expr) must arm every dependency family at once: ordinary signals,
// virtual-interface members, and dynamic class-property mutations.
interface mixed_wait_if;
  logic signal;
endinterface

class mixed_wait_state;
  virtual mixed_wait_if vif;
  static bit ordinary_gate;
  bit watched;
  bit active;
  bit vif_woke;
  bit all_families_woke;

  task watch_vif(bit old_signal);
    wait (vif.signal != old_signal && !active);
    vif_woke = 1;
  endtask

  task watch_all_families(bit old_signal);
    wait (vif.signal != old_signal && !active && ordinary_gate);
    all_families_woke = 1;
  endtask
endclass

module sv_class_property_mixed_wait_value_change;
  mixed_wait_if vif();
  mixed_wait_state state;
  bit ordinary;
  bit property_first_woke;
  bit signal_first_woke;
  int cancellation_stress_wakes;
  int property_winner_stress_wakes;
  bit root_rebind_woke;

  initial begin
    state = new;
    state.vif = vif;

    fork
      begin
        wait (state.watched && ordinary);
        property_first_woke = 1;
      end
    join_none
    #1;
    state.watched = 1;
    #1;
    if (property_first_woke) begin
      $display("FAILED: property-first wait ignored ordinary signal");
      $finish;
    end
    ordinary = 1;
    #1;
    if (!property_first_woke) begin
      $display("FAILED: ordinary signal did not finish mixed wait");
      $finish;
    end

    state.watched = 0;
    ordinary = 0;
    fork
      begin
        wait (state.watched && ordinary);
        signal_first_woke = 1;
      end
    join_none
    #1;
    ordinary = 1;
    #1;
    if (signal_first_woke) begin
      $display("FAILED: signal-first wait ignored class property");
      $finish;
    end
    state.watched = 1;
    #1;
    if (!signal_first_woke) begin
      $display("FAILED: class property did not finish mixed wait");
      $finish;
    end

    state.active = 1;
    fork
      state.watch_vif(0);
    join_none
    #1;
    vif.signal = 1;
    #1;
    if (state.vif_woke) begin
      $display("FAILED: VIF edge ignored class-property guard");
      $finish;
    end
    state.active = 0;
    #1;
    if (!state.vif_woke) begin
      $display("FAILED: class mutation did not finish VIF/property wait");
      $finish;
    end

    state.active = 1;
    mixed_wait_state::ordinary_gate = 0;
    vif.signal = 0;
    fork
      state.watch_all_families(0);
    join_none
    #1;
    vif.signal = 1;
    #1;
    mixed_wait_state::ordinary_gate = 1;
    #1;
    if (state.all_families_woke) begin
      $display("FAILED: VIF/ordinary changes ignored class-property guard");
      $finish;
    end
    state.active = 0;
    #1;
    if (!state.all_families_woke) begin
      $display("FAILED: three-family wait did not observe every dependency");
      $finish;
    end

    // Repeatedly make each waiter family win in turn. Every iteration must
    // cancel and unlink the losing child before the next wait arms.
    for (int iteration = 0; iteration < 200; iteration++) begin
      state.watched = 0;
      ordinary = 0;
      fork
        begin
          wait (state.watched && ordinary);
          cancellation_stress_wakes++;
        end
      join_none
      #1;
      if (iteration[0]) begin
        state.watched = 1;
        #1;
        ordinary = 1;
      end else begin
        ordinary = 1;
        #1;
        state.watched = 1;
      end
      #1;
      if (cancellation_stress_wakes != iteration + 1) begin
        $display("FAILED: mixed-wait cancellation stress iteration %0d",
                 iteration);
        $finish;
      end
    end

    // Keep the ordinary signal quiet while the property side wins every
    // time. A disabled ordinary-event child must be removed immediately;
    // it cannot remain queued until some future ordinary edge.
    ordinary = 1;
    for (int iteration = 0; iteration < 2000; iteration++) begin
      state.watched = 0;
      fork
        begin
          wait (state.watched && ordinary);
          property_winner_stress_wakes++;
        end
      join_none
      #1;
      state.watched = 1;
      #1;
      if (property_winner_stress_wakes != iteration + 1) begin
        $display("FAILED: property-winner stress iteration %0d", iteration);
        $finish;
      end
    end

    // Replacing a nonautomatic root handle is an ordinary operand change.
    // The waiter must leave the old object and re-evaluate on the new one.
    begin
      mixed_wait_state replacement;
      state.watched = 0;
      fork
        begin
          wait (state.watched);
          root_rebind_woke = 1;
        end
      join_none
      #1;
      replacement = new;
      replacement.vif = vif;
      replacement.watched = 1;
      state = replacement;
      #1;
      if (!root_rebind_woke) begin
        $display("FAILED: class root replacement did not re-arm wait");
        $finish;
      end
    end

    $display("PASSED");
  end
endmodule
