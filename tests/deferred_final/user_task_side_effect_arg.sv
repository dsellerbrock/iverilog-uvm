module deferred_final_user_task_side_effect_arg;
  int value;

  function int bump;
    value += 1;
    return value;
  endfunction

  task report;
    $display("VALUE=%0d", bump());
  endtask

  initial assert final (0) else report();
endmodule
