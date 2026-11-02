module issue2223_event_function_operand;
  logic [3:0] sig = 0;
  int calls = 0;
  bit fired = 0;

  function automatic int f();
    calls++;
    return 1;
  endfunction

  initial begin
    fork
      begin
        @(posedge sig[f()]);
        fired = 1;
      end
    join_none

    #1 sig[2] = 1;
    #1;
    if (calls != 2)
      $fatal(1, "f() was evaluated %0d times, expected 2", calls);
    if (fired)
      $fatal(1, "event fired on a change to an unselected bit");
    $display("PASSED");
    $finish;
  end
endmodule
