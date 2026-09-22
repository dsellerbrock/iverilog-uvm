module sv_whole_function_event_nested_rebind;
  class child_t; int idx; endclass
  class cfg_t;
    child_t child;
    function automatic int selector(); return child.idx; endfunction
  endclass
  cfg_t cfg;
  child_t old_child, new_child;
  logic [1:0] data;
  int wakes;
  task automatic waiter; @(data[cfg.selector()]); wakes++; endtask
  initial begin
    cfg = new; old_child = new; new_child = new;
    old_child.idx = 0; new_child.idx = 0; cfg.child = old_child; data = '0;
    fork waiter(); join_none
    #1;
    data[1] = 1;
    cfg.child = new_child;
    #0 if (wakes != 0) $fatal(1, "equal-value child rebind woke waiter");
    old_child.idx = 1;
    #0 if (wakes != 0) $fatal(1, "detached child mutation woke waiter");
    new_child.idx = 1;
    #0 if (wakes != 1) $fatal(1, "replacement child mutation was missed");
    $display("PASS whole-function-nested-rebind");
    $finish;
  end
endmodule
