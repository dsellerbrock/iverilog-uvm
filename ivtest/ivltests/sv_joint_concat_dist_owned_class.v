// IEEE 1800-2017 18.5.4 and 2023 18.5.3: a dist subject can be a
// concatenation of rand properties, even in a joint solve with an owned class.
class concat_dist_leaf;
  rand bit value;
endclass

class concat_dist_root;
  rand bit [3:0] boot_mode, auto_mode;
  rand concat_dist_leaf child;

  function new;
    child = new;
  endfunction

  constraint mode_c {
    {boot_mode, auto_mode} dist {8'h12 := 1, 8'h34 := 3};
  }
endclass

class staged_bit_dist_leaf;
  rand bit value;
endclass

class staged_bit_dist_root;
  rand bit [7:0] early, late;
  rand staged_bit_dist_leaf child;

  function new;
    child = new;
  endfunction

  constraint bit_weights {
    early[0] dist {0 := 1, 1 := 9};
    early[1] dist {0 := 9, 1 := 1};
  }
  constraint order_c { solve early before late; }
  constraint correlation_c { late == early; child.value == early[2]; }
endclass

class staged_projection_cover;
  rand bit [7:0] max_v, min_v;
  rand bit [15:0] late;

  constraint bit_weights {
    foreach (max_v[i]) max_v[i] dist {0 := 29, 1 := 1};
    foreach (min_v[i]) min_v[i] dist {0 := 29, 1 := 1};
  }
  constraint disjoint_c { (max_v & min_v) == 0; }
  constraint order_c { solve max_v, min_v before late; }
  constraint late_c { late inside {[0:100]}; }
endclass

class staged_projection_parent;
  rand staged_projection_cover cfg;

  function new;
    cfg = new;
  endfunction
endclass

module sv_joint_concat_dist_owned_class;
  concat_dist_root cfg;
  staged_bit_dist_root staged;
  staged_projection_parent coverage_cfg;
  int high_count, child_ones, early_ones, early_bit1_ones;

  initial begin
    cfg = new;
    staged = new;
    coverage_cfg = new;
    cfg.srandom(32'h45444e31);
    cfg.child.srandom(32'h45444e32);
    staged.srandom(32'h45444e33);
    staged.child.srandom(32'h45444e34);
    coverage_cfg.srandom(32'h45444e35);
    if (!coverage_cfg.randomize())
      $fatal(1, "complete staged bit projection coverage failed");
    if ((coverage_cfg.cfg.max_v & coverage_cfg.cfg.min_v) != 0)
      $fatal(1, "complete staged bit projection overlap");
    repeat (512) begin
      if (!cfg.randomize()) $fatal(1, "joint concat distribution failed");
      if ({cfg.boot_mode, cfg.auto_mode} != 8'h12 &&
          {cfg.boot_mode, cfg.auto_mode} != 8'h34)
        $fatal(1, "illegal mode pair %h", {cfg.boot_mode, cfg.auto_mode});
      if ({cfg.boot_mode, cfg.auto_mode} == 8'h34) high_count++;
      child_ones += cfg.child.value;
    end
    repeat (1024) begin
      if (!staged.randomize()) $fatal(1, "staged bit projection dist failed");
      if (staged.late !== staged.early ||
          staged.child.value !== staged.early[2])
        $fatal(1, "staged bit projection correlation");
      early_ones += staged.early[0];
      early_bit1_ones += staged.early[1];
    end
    if (high_count < 320 || high_count > 450 ||
        child_ones < 200 || child_ones > 312 ||
        early_ones < 850 || early_ones > 1000 ||
        early_bit1_ones < 70 || early_bit1_ones > 135)
      $fatal(1, "joint dist high=%0d child=%0d staged=%0d/%0d",
             high_count, child_ones, early_ones, early_bit1_ones);
    $display("PASSED");
  end
endmodule
