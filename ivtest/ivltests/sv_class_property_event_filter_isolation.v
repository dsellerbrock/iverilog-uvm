// Distinct property event controls on the same class handle must retain
// distinct sensitivity metadata when the compiler deduplicates event probes.
class class_property_event_filter_state;
  bit first;
  bit second;
  bit unrelated;
  int stage;

  task watch_in_order;
    @(first);
    stage = 1;
    @(second);
    stage = 2;
  endtask
endclass

module sv_class_property_event_filter_isolation;
  class_property_event_filter_state state;

  initial begin
    state = new;

    fork
      state.watch_in_order();
    join_none

    #1;
    state.unrelated = 1'b1;
    #1;
    if (state.stage != 0) begin
      $fatal(1, "unrelated property woke a filtered event: stage=%0d",
             state.stage);
    end

    state.first = 1'b1;
    #1;
    if (state.stage != 1) begin
      $fatal(1, "first property did not wake first event: stage=%0d",
             state.stage);
    end

    state.second = 1'b1;
    #1;
    if (state.stage != 2) begin
      $fatal(1, "second property did not retain its own event filter: stage=%0d",
             state.stage);
    end

    $display("PASSED");
  end
endmodule
