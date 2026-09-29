class unrelated_order_child;
  rand bit zero, delay_max;
  constraint order_c {
    solve zero before delay_max;
    delay_max == zero;
  }
endclass

class unrelated_order_parent;
  rand int unsigned clk;
  rand unrelated_order_child child;
  function new; child = new; endfunction
  constraint frequency { clk dist {[48:50] :/ 2}; clk == 50; }
endclass

module sv_randomize_joint_unordered_dist_clipped;
  unrelated_order_parent cfg = new;
  int zeros, ones;
  initial begin
    repeat (64) begin
      if (!cfg.randomize() || cfg.clk != 50 ||
          cfg.child.delay_max != cfg.child.zero)
        $fatal(1, "independent fixed range must randomize");
      if (cfg.child.zero) ones++;
      else zeros++;
    end
    if (!zeros || !ones) $fatal(1, "child order lost variability");
    $display("PASSED");
  end
endmodule
