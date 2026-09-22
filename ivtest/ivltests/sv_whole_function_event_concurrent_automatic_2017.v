module sv_whole_function_event_concurrent_automatic;
  class cfg_t;
    logic value;
    function automatic logic value_fn(); return value; endfunction
  endclass
  cfg_t left, right;
  int left_wakes, right_wakes;
  task automatic wait_left;  @(left.value_fn());  left_wakes++;  endtask
  task automatic wait_right; @(right.value_fn()); right_wakes++; endtask
  initial begin
    left = new; right = new; left.value = 0; right.value = 0;
    fork wait_left(); wait_right(); join_none
    #1;
    left.value = 1;
    #0 if (left_wakes != 1 || right_wakes != 0) $fatal(1, "automatic waits aliased left=%0d right=%0d", left_wakes, right_wakes);
    right.value = 1;
    #0 if (left_wakes != 1 || right_wakes != 1) $fatal(1, "whole integral function waits incorrect left=%0d right=%0d", left_wakes, right_wakes);
    $display("PASS whole-function-concurrent-automatic");
    $finish;
  end
endmodule
