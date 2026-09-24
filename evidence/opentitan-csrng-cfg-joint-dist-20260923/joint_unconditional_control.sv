class unconditional_dist_leaf;
  rand bit [1:0] value;
  constraint value_dist_c { value dist {0 := 1, 1 := 3}; }
endclass

class unconditional_dist_root;
  rand unconditional_dist_leaf a;
  rand unconditional_dist_leaf b;
  constraint couple_c { a.value == b.value; }
endclass

module top;
  initial begin
    unconditional_dist_root cfg;
    cfg = new;
    cfg.a = new;
    cfg.b = new;
    repeat (8) begin
      if (!cfg.randomize()) $fatal(1, "unconditional nested dist should solve");
      if (cfg.a.value != cfg.b.value || cfg.a.value > 1)
        $fatal(1, "unconditional nested dist produced an illegal value");
    end
    $display("PASS nested unconditional dist");
    $finish;
  end
endmodule
