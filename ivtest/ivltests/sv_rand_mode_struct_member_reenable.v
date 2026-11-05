typedef struct {
  rand bit [7:0] a;
  rand bit [7:0] b;
} rand_mode_reenable_record_t;

class rand_mode_reenable_unconstrained_item;
  rand rand_mode_reenable_record_t r;
endclass

class rand_mode_reenable_item;
  rand rand_mode_reenable_record_t r;
  bit [7:0] previous_b;

  constraint b_must_change {
    r.b != previous_b;
  }
endclass

module test;
  initial begin
    rand_mode_reenable_unconstrained_item unconstrained_item;
    rand_mode_reenable_item item;
    bit [7:0] held_a;
    bit [7:0] previous_b;
    int changed;

    unconstrained_item = new;
    unconstrained_item.r.a = 8'h5a;
    unconstrained_item.r.b = 8'h00;
    unconstrained_item.r.rand_mode(0);
    unconstrained_item.r.b.rand_mode(1);
    if (unconstrained_item.r.a.rand_mode() !== 0
        || unconstrained_item.r.b.rand_mode() !== 1)
      $fatal(1, "member rand_mode did not override the struct mode");

    held_a = unconstrained_item.r.a;
    previous_b = unconstrained_item.r.b;
    changed = 0;
    for (int i = 0; i < 20; i++) begin
      if (!unconstrained_item.randomize())
        $fatal(1, "active unconstrained struct member failed to randomize");
      if (unconstrained_item.r.a !== held_a)
        $fatal(1, "inactive unconstrained struct member was randomized");
      if (unconstrained_item.r.b !== previous_b)
        changed++;
      previous_b = unconstrained_item.r.b;
    end
    if (changed == 0)
      $fatal(1, "re-enabled unconstrained member was never randomized");

    item = new;
    item.r.a = 8'h5a;
    item.r.b = 8'h00;
    item.previous_b = item.r.b;

    item.r.rand_mode(0);
    item.r.b.rand_mode(1);
    if (item.r.a.rand_mode() !== 0 || item.r.b.rand_mode() !== 1)
      $fatal(1, "member rand_mode did not override the struct mode");

    held_a = item.r.a;
    item.previous_b = item.r.b;
    for (int i = 0; i < 20; i++) begin
      if (!item.randomize())
        $fatal(1, "active constrained struct member failed to randomize");
      if (item.r.a !== held_a)
        $fatal(1, "inactive struct member was randomized");
      if (item.r.b === item.previous_b)
        $fatal(1, "re-enabled struct member was not randomized");
      item.previous_b = item.r.b;
    end

    $display("PASS struct-member-rand-mode-reenable");
  end
endmodule
