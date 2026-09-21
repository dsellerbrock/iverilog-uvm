module top;
  class leaf_t; logic [1:0] bits; endclass
  class cfg_t;
    logic choose; int calls; int idx; leaf_t left, right;
    function automatic int selector(); calls++; return idx; endfunction
  endclass
  cfg_t cfg = new;
  int wakes_a, wakes_b;
  task automatic waiter_a;
    @(cfg.choose ? cfg.right.bits[cfg.selector()] : cfg.left.bits[0]); wakes_a++;
  endtask
  task automatic waiter_b;
    @(cfg.choose ? cfg.right.bits[cfg.selector()] : cfg.left.bits[0]); wakes_b++;
  endtask
  initial begin
    cfg.left=new; cfg.right=new; cfg.left.bits=0; cfg.right.bits=0;
    cfg.choose=0; cfg.idx=0; cfg.calls=0;
    fork waiter_a(); waiter_b(); join_none
    #1 begin
      if (cfg.calls != 0) $fatal(1, "unselected selector executed");
      cfg.choose=1; cfg.right.bits[0]=1;
    end
    #1 begin
      if (wakes_a != 1 || wakes_b != 1) $fatal(1, "conditional capture lost immediate mutation %0d/%0d", wakes_a, wakes_b);
      $display("PASS conditional-capture"); $finish(0);
    end
  end
endmodule
