class phase_t;
  typedef bit edges_t[phase_t];
  edges_t succs;
endclass

class schedule_t;
  phase_t end_node;

  function new();
    end_node = new();
  endfunction
endclass

module test;
  initial begin
    bit found;
    phase_t leaf;
    schedule_t sched;

    found = 1'b0;
    leaf = new();
    sched = new();
    sched.end_node.succs[leaf] = 1'b1;

    foreach (sched.end_node.succs[key]) begin
      if (key == leaf)
        found = 1'b1;
    end

    if (found) begin
      $display("PASSED");
    end else begin
      $display("NESTED_FAIL");
      $finish(1);
    end
  end
endmodule
