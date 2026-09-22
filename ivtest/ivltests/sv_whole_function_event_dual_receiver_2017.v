module sv_whole_function_event_dual_receiver;
  class leaf_t;
    logic a, b;
    function automatic logic read_a(); return a; endfunction
    function automatic logic read_b(); return b; endfunction
  endclass
  leaf_t shared;
  function automatic leaf_t receiver(); return shared; endfunction
  int a_wakes, b_wakes;
  task automatic wait_a; @(receiver().read_a()); a_wakes++; endtask
  task automatic wait_b; @(receiver().read_b()); b_wakes++; endtask
  initial begin
    shared = new; shared.a = 0; shared.b = 0;
    fork wait_a(); wait_b(); join_none
    #1;
    shared.a = 1;
    #0 if (a_wakes != 1 || b_wakes != 0) $fatal(1, "read_a mutation aliases observer recipes a=%0d b=%0d", a_wakes, b_wakes);
    shared.b = 1;
    #0 if (a_wakes != 1 || b_wakes != 1) $fatal(1, "read_b mutation did not wake its distinct recipe a=%0d b=%0d", a_wakes, b_wakes);
    $display("PASS whole-function-dual-receiver");
    $finish;
  end
endmodule
