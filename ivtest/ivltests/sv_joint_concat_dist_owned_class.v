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

module sv_joint_concat_dist_owned_class;
  concat_dist_root cfg;
  int high_count, child_ones;

  initial begin
    cfg = new;
    cfg.srandom(32'h45444e31);
    cfg.child.srandom(32'h45444e32);
    repeat (512) begin
      if (!cfg.randomize()) $fatal(1, "joint concat distribution failed");
      if ({cfg.boot_mode, cfg.auto_mode} != 8'h12 &&
          {cfg.boot_mode, cfg.auto_mode} != 8'h34)
        $fatal(1, "illegal mode pair %h", {cfg.boot_mode, cfg.auto_mode});
      if ({cfg.boot_mode, cfg.auto_mode} == 8'h34) high_count++;
      child_ones += cfg.child.value;
    end
    if (high_count < 320 || high_count > 450 ||
        child_ones < 200 || child_ones > 312)
      $fatal(1, "joint dist high=%0d child=%0d", high_count, child_ones);
    $display("PASSED");
  end
endmodule
