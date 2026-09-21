// Metadata acceptance: two compound class events share cfg.a/cfg.b pins but
// observe distinct values. The OR waiter must not wake when only the sum changes.
module top;
  class cfg_t;
    logic a;
    logic b;
  endclass
  cfg_t cfg = new;
  bit sum_done, or_done;

  task automatic wait_sum;
    @(cfg.a + cfg.b);
    sum_done = 1;
  endtask

  task automatic wait_or;
    @(cfg.a | cfg.b);
    or_done = 1;
  endtask

  initial begin
    cfg.a = 0;
    cfg.b = 1;
    fork
      wait_sum();
      wait_or();
    join_none
    #1 cfg.a = 1;                  // sum 1 -> 2, OR remains 1
    #1 begin
      if (!sum_done || or_done) $fatal(1, "distinct observer expressions merged");
      cfg.a = 0;
      cfg.b = 0;                   // OR 1 -> 0
    end
    #1 begin
      if (!or_done) $fatal(1, "OR observer did not receive its value change");
      $display("PASS samepins-differentexpr");
      $finish(0);
    end
  end
endmodule
