module core_automatic_cancel;
  class cfg_t; logic on; endclass
  class agent_t;
    cfg_t cfg;
    logic [1:0] pulses;
    int id;
    int wakes;
    function new(input int n); id = n; cfg = new; endfunction
    task automatic wait_one(input int expected);
      int local_id = id;
      @(cfg.on, pulses);
      if (local_id != expected || id != expected) $fatal(1, "automatic context crossed");
      wakes++;
    endtask
  endclass
  agent_t a, b, killed;
  initial begin
    a = new(1); b = new(2); killed = new(3);
    fork : wait_a a.wait_one(1); join_none
    fork : wait_b b.wait_one(2); join_none
    fork : wait_killed killed.wait_one(3); join_none
    #1 disable wait_killed;
    a.cfg.on = 1'b1;
    b.pulses = 2'b10;
    killed.cfg.on = 1'b1;
    killed.pulses = 2'b11;
    #1;
    if (a.wakes != 1 || b.wakes != 1 || killed.wakes != 0)
      $fatal(1, "activation isolation/cancellation failed %0d %0d %0d", a.wakes, b.wakes, killed.wakes);
    $display("PASS core automatic cancel");
    $finish;
  end
endmodule
