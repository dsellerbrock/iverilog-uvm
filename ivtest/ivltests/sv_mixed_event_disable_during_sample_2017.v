module top;
  class cfg_t;
    int idx;
    bit kill_on_eval;
    bit [1:0] bits;
    function bit selector();
      selector = idx[0];
      if (kill_on_eval) begin
        kill_on_eval = 0;
        disable top.waiting_process;
      end
    endfunction
  endclass

  cfg_t cfg;
  bit wait_body_ran;
  bit independent_completed;

  initial begin
    cfg = new;
    cfg.idx = 0;
    cfg.kill_on_eval = 0;
    cfg.bits = 2'b00;

    fork
      begin : waiting_process
        @(cfg.bits[cfg.selector()]);
        wait_body_ran = 1;
      end
    join_none

    // Releases the child after it has armed, then the class mutation invokes
    // selector() in the synchronous recipe. selector() kills that same parked
    // process while the recipe frame and waiter are both pinned.
    #1 cfg.kill_on_eval = 1;

    fork
      begin
        #1 independent_completed = 1;
      end
    join

    #1;
    if (wait_body_ran)
      $fatal(1, "killed event waiter executed its body");
    if (!independent_completed)
      $fatal(1, "independent process did not complete");
    $display("PASSED");
  end
endmodule
