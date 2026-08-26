// A compound class-property event changes only when the complete expression
// changes, not whenever one of its masked leaves is written.
class compound_event_state;
  bit left;
  bit right;
  bit woke;

  task watch;
    @(left || right);
    woke = 1;
  endtask
endclass

module sv_class_property_compound_event_value_change;
  compound_event_state state;
  initial begin
    state = new;
    state.left = 1;
    fork
      state.watch();
    join_none

    #1;
    state.right = 1;
    #1;
    if (state.woke) begin
      $display("FAILED: masked right-property mutation woke event");
      $finish;
    end

    state.left = 0;
    #1;
    if (state.woke) begin
      $display("FAILED: masked left-property mutation woke event");
      $finish;
    end

    state.right = 0;
    #1;
    if (!state.woke) begin
      $display("FAILED: expression value change did not wake event");
      $finish;
    end

    $display("PASSED");
  end
endmodule
