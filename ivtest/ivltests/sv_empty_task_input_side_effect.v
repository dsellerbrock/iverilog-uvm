// IEEE 1800-2017/2023 13.5: invoking an empty native task still evaluates
// each supplied input actual. An empty body cannot erase caller side effects.
module sv_empty_task_input_side_effect;
  int evaluations;

  function automatic int evaluate_actual();
    evaluations++;
    return evaluations;
  endfunction

  task automatic consume(input int unused);
  endtask

  initial begin
    consume(evaluate_actual());
    consume(evaluate_actual());

    if (evaluations == 2)
      $display("PASSED");
    else
      $fatal(1, "FAILED: empty task evaluated %0d input actuals", evaluations);
  end
endmodule
