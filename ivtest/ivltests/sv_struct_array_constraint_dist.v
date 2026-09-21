// IEEE 1800-2017 18.5.4 and 18.5.10; IEEE 1800-2023 18.5.3 and 18.5.9.
typedef struct {
  rand bit pick[1:0];
  rand bit key;
  rand bit dependent[1:0];
} dist_order_member_arrays_t;

class dist_order_soft;
  rand dist_order_member_arrays_t cfg;

  constraint zero_weight_and_order {
    foreach (cfg.pick[i]) cfg.pick[i] dist {1'b0 :/ 1, 1'b1 :/ 0};
    solve cfg.key before cfg.dependent[1];
    cfg.key == 0;
    soft cfg.dependent[1] == 1;
    cfg.dependent[1] == cfg.key;
  }
endclass

module dist_order_soft_test;
  initial begin
    static dist_order_soft item = new;
    if (!item.randomize()) $fatal(1, "dist/order member-array randomize failed");
    foreach (item.cfg.pick[i])
      if (item.cfg.pick[i] !== 0)
        $fatal(1, "zero-weight member-array value selected at %0d", i);
    if (item.cfg.key !== 0 || item.cfg.dependent[1] !== 0)
      $fatal(1, "selected solve-before or soft identity changed");
    $display("PASS dist-order-soft");
  end
endmodule
