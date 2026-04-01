class phase_t;
  typedef bit edges_t[phase_t];
  edges_t preds;
  edges_t succs;

  function void connect_to(phase_t other);
    succs[other] = 1;
    other.preds[this] = 1;
  endfunction

  function void insert_before(phase_t before_phase,
                              phase_t begin_node,
                              phase_t end_node);
    foreach (before_phase.preds[pred]) begin
      pred.succs.delete(before_phase);
      pred.succs[begin_node] = 1;
    end
    begin_node.preds = before_phase.preds;
    before_phase.preds.delete();
    before_phase.preds[end_node] = 1;
    end_node.succs.delete();
    end_node.succs[before_phase] = 1;
  endfunction
endclass

module test;
  initial begin
    bit found_key;
    phase_t schedule;
    phase_t finish;
    phase_t new_begin;
    phase_t new_end;
    phase_t found;

    schedule = new();
    finish = new();
    new_begin = new();
    new_end = new();
    found_key = 1'b0;

    schedule.connect_to(finish);
    schedule.insert_before(finish, new_begin, new_end);

    foreach (schedule.succs[found]) begin
      if (found == new_begin)
        found_key = 1'b1;
    end

    if (found_key) begin
      $display("PASSED");
    end else begin
      $display("GRAPH_FAIL");
      $finish(1);
    end
  end
endmodule
