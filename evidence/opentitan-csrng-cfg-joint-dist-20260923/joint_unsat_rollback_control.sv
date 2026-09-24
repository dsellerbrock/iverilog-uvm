class rollback_dist_leaf;
  rand bit [1:0] value;
  constraint value_dist_c { value dist {0 := 1, 1 := 1}; }
endclass

class rollback_dist_root;
  rand rollback_dist_leaf a;
  rand rollback_dist_leaf b;
  constraint couple_c { a.value == b.value; }
  constraint impossible_c { a.value == 0; a.value == 1; }
endclass

module top;
  initial begin
    rollback_dist_root cfg;
    cfg = new;
    cfg.a = new;
    cfg.b = new;
    cfg.a.value = 2;
    cfg.b.value = 3;
    if (cfg.randomize()) $fatal(1, "impossible constraints unexpectedly solved");
    if (cfg.a.value != 2 || cfg.b.value != 3)
      $fatal(1, "failed randomize did not preserve prior values");
    $display("PASS joint UNSAT rollback");
    $finish;
  end
endmodule
