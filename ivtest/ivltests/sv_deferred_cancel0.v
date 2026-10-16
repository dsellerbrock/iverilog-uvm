module sv_deferred_cancel_level_child(output bit queued);
  initial begin : child_process
    begin : nested_child
      assert #0 (1'b0) else $display("LEVEL_CHILD_REPORT");
      queued = 1;
    end
  end
endmodule

module sv_deferred_cancel0;
  bit outer_queued, sibling_queued;
  bit level_parent_queued, level_child_queued;
  event both_queued;

  sv_deferred_cancel_level_child level_child(level_child_queued);

  initial begin : level_parent_process
    begin : nested_parent
      assert #0 (1'b0) else $display("LEVEL_PARENT_REPORT");
      level_parent_queued = 1;
    end
  end

  initial begin : level_kill_process
    wait (level_parent_queued && level_child_queued);
    #0;
    $assertkill(1, sv_deferred_cancel0);
  end

  function void queue_outer_function_reports;
    function_a: assert #0 (1) $display("OUTER_FUNCTION_A");
    function_final_a: assert final (1) $display("OUTER_FUNCTION_FINAL_A");
  endfunction

  initial begin : label_process
    #1;
    label_a: assert #0 (1) $display("LABEL_A");
    label_final_a: assert final (1) $display("LABEL_FINAL_A");
    label_b: assert #0 (1) $display("LABEL_B");
    label_final_b: assert final (1) $display("LABEL_FINAL_B");
    disable label_a;
    disable label_final_a;
  end

  initial begin : outer_process
    #2;
    queue_outer_function_reports();
    outer_a: assert #0 (1) $display("OUTER_A");
    outer_final_a: assert final (1) $display("OUTER_FINAL_A");
    outer_b: assert #0 (1) $display("OUTER_B");
    outer_final_b: assert final (1) $display("OUTER_FINAL_B");
    outer_queued = 1;
    if (sibling_queued) -> both_queued;
    #0;
    $display("OUTER_PROCESS_CONTINUED");
  end

  initial begin : sibling_process
    #2;
    sibling_a: assert #0 (1) $display("SIBLING_A");
    sibling_final_a: assert final (1) $display("SIBLING_FINAL_A");
    sibling_queued = 1;
    if (outer_queued) -> both_queued;
    #0;
    $display("SIBLING_PROCESS_CONTINUED");
  end

  initial begin
    @both_queued;
    disable sv_deferred_cancel0.outer_process;
  end

  initial begin : nested_process
    #3;
    begin : nested_block
      nested_a: assert #0 (1) $display("NESTED_A");
      nested_final_a: assert final (1) $display("NESTED_FINAL_A");
      disable nested_block;
      $display("NESTED_BLOCK_CONTINUED");
    end
    nested_b: assert #0 (1) $display("NESTED_B");
    nested_final_b: assert final (1) $display("NESTED_FINAL_B");
  end

  initial begin : kill_process
    #4;
    kill_a: assert #0 (1) $display("KILL_A");
    kill_final_a: assert final (1) $display("KILL_FINAL_A");
    kill_b: assert #0 (1) $display("KILL_B");
    kill_final_b: assert final (1) $display("KILL_FINAL_B");
    keep_final: assert final (1) $display("KILL_FINAL_KEEP");
    $assertkill(0, sv_deferred_cancel0.kill_process.kill_b);
    $assertkill(0, sv_deferred_cancel0.kill_process.kill_final_b);
  end
endmodule
