// Metadata acceptance: an automatic task observes the full integral system
// function expression, rather than a deferred snapshot of cfg.bits.
module top;
  class cfg_t;
    logic [2:0] bits;
  endclass
  cfg_t cfg = new;
  bit done;

  task automatic wait_count;
    @( $countones(cfg.bits) );
    done = 1;
  endtask

  initial begin
    cfg.bits = 3'b000;
    fork
      wait_count();
    join_none
    #1 cfg.bits = 3'b101;
    #1 begin
      if (!done) $fatal(1, "automatic full-expression observer did not wake");
      $display("PASS automatic-sfunc-expression");
      $finish(0);
    end
  end
endmodule
