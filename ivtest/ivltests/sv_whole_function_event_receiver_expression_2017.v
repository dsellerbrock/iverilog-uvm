module sv_whole_function_event_receiver_expression;
  class leaf_t;
    logic [1:0] data;
    int idx;
    function automatic logic selected(); return data[idx]; endfunction
  endclass
  class owner_t;
    leaf_t leaf;
    int receiver_calls;
    function automatic leaf_t receiver(); receiver_calls++; return leaf; endfunction
  endclass
  owner_t cfg;
  int wakes;
  task automatic waiter;
    @(cfg.receiver().selected());
    wakes++;
  endtask
  initial begin
    cfg = new; cfg.leaf = new; cfg.leaf.data = '0; cfg.leaf.idx = 0; cfg.receiver_calls = 0;
    fork waiter(); join_none
    #1;
    if (cfg.receiver_calls != 1) $fatal(1, "receiver expression evaluated %0d times while arming", cfg.receiver_calls);
    cfg.leaf.data[0] = 0;
    cfg.leaf.data[1] = 1;
    #0 if (wakes != 0) $fatal(1, "equal or unselected leaf mutation woke waiter");
    cfg.leaf.data[0] = 1;
    #0 if (wakes != 1) $fatal(1, "selected returned-receiver mutation was missed");
    $display("PASS whole-function-receiver-expression");
    $finish;
  end
endmodule
